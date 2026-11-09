import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../sales/models/dish.dart';
import '../../sales/models/sale.dart';
import '../../sales/repositories/dish_repository.dart';
import '../../sales/repositories/sale_repository.dart';
import '../../sales/screens/operation_detail_screen.dart';
import '../../sales/screens/payment_screen.dart';

class ClientShopScreen extends StatefulWidget {
  const ClientShopScreen({super.key, required this.clientUserId});
  final int clientUserId;
  @override
  State<ClientShopScreen> createState() => _ClientShopScreenState();
}

class _ClientShopScreenState extends State<ClientShopScreen> {
  List<Map<String, Object?>> _restaurants = [];
  List<Dish> _dishes = [];
  int? _restaurantId;
  final Map<int, int> _cart = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final rows = await (await DatabaseHelper.instance.database).query(
        'restaurants',
        where: "statut = 'actif'",
        orderBy: 'nom',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _restaurants = rows;
        _restaurantId = rows.isEmpty ? null : rows.first['id'] as int;
        _loading = false;
      });
      if (_restaurantId != null) {
        await _loadDishes(_restaurantId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadDishes(int id) async {
    try {
      final rows = await DishRepository().forRestaurant(id);
      if (mounted) setState(() => _dishes = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  int get _subtotal =>
      _dishes.fold(0, (sum, dish) => sum + dish.price * (_cart[dish.id] ?? 0));
  int get _discount => _subtotal >= 50000 ? (_subtotal * 10 / 100).round() : 0;
  int get _total => _subtotal - _discount;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Commander'),
      actions: [
        IconButton(
          tooltip: 'Mes achats',
          icon: const Icon(Icons.receipt_long),
          onPressed: _openOrders,
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text('Erreur : $_error'))
        : _restaurants.isEmpty
        ? const Center(child: Text('Aucun restaurant disponible.'))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<int>(
                  initialValue: _restaurantId,
                  decoration: const InputDecoration(labelText: 'Restaurant'),
                  items: _restaurants
                      .map(
                        (r) => DropdownMenuItem<int>(
                          value: r['id'] as int,
                          child: Text(r['nom'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _restaurantId = id;
                      _cart.clear();
                      _dishes = [];
                    });
                    _loadDishes(id);
                  },
                ),
              ),
              Expanded(
                child: _dishes.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun plat disponible pour ce restaurant.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _dishes.length,
                        itemBuilder: (context, index) {
                          final dish = _dishes[index];
                          final quantity = _cart[dish.id] ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(dish.name),
                              subtitle: Text(
                                '${(dish.price / 1000).toStringAsFixed(3)} DT${dish.description.isEmpty ? '' : ' • ${dish.description}'}',
                              ),
                              trailing: quantity == 0
                                  ? IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      onPressed: () =>
                                          setState(() => _cart[dish.id!] = 1),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          onPressed: () => setState(() {
                                            if (quantity <= 1) {
                                              _cart.remove(dish.id);
                                            } else {
                                              _cart[dish.id!] = quantity - 1;
                                            }
                                          }),
                                        ),
                                        Text('$quantity'),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onPressed: () => setState(
                                            () =>
                                                _cart[dish.id!] = quantity + 1,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
    bottomNavigationBar: _cart.isEmpty
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _checkout,
                icon: const Icon(Icons.payment),
                label: Text(
                  'Payer · ${(_total / 1000).toStringAsFixed(3)} DT${_discount > 0 ? ' (remise 10 %)' : ''}',
                ),
              ),
            ),
          ),
  );

  Future<void> _checkout() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null || _cart.isEmpty) return;
    try {
      final selected = _dishes.where((d) => _cart.containsKey(d.id)).toList();
      final sale = Sale(
        restaurantId: restaurantId,
        date: DateTime.now(),
        clientUserId: widget.clientUserId,
        lines: selected
            .map(
              (d) => SaleLine(
                designation: d.name,
                quantity: (_cart[d.id] ?? 0).toDouble(),
                unitPrice: d.price,
                dishId: d.id,
              ),
            )
            .toList(),
      );
      final id = await SaleRepository().create(sale);
      final restaurant = _restaurants
          .firstWhere((r) => r['id'] == restaurantId)['nom']
          .toString();
      if (!mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            saleId: id,
            total: sale.total,
            restaurant: restaurant,
            subtotal: sale.subtotal,
            discount: sale.discount,
          ),
        ),
      );
      if (mounted) setState(() => _cart.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientOrdersScreen(clientUserId: widget.clientUserId),
      ),
    );
  }
}

class _ClientOrdersScreen extends StatefulWidget {
  const _ClientOrdersScreen({required this.clientUserId});
  final int clientUserId;
  @override
  State<_ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<_ClientOrdersScreen> {
  late Future<List<Map<String, Object?>>> _orders = SaleRepository().forClient(
    widget.clientUserId,
  );
  void _refresh() =>
      setState(() => _orders = SaleRepository().forClient(widget.clientUserId));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mes achats')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text('Vous n’avez pas encore de commande.'),
          );
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final id = order['id'] as int;
            final pending = order['statut'] == 'en_attente';
            return Card(
              child: ListTile(
                title: Text(order['restaurant'].toString()),
                subtitle: Text(
                  'Commande #$id · ${pending ? 'Paiement en attente' : 'Payée'}',
                ),
                trailing: pending
                    ? TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentScreen(
                                saleId: id,
                                total: order['total'] as int,
                                restaurant: order['restaurant'].toString(),
                                subtotal: order['sous_total'] as int?,
                                discount: (order['remise'] as int?) ?? 0,
                              ),
                            ),
                          );
                          if (mounted) _refresh();
                        },
                        child: const Text('Payer'),
                      )
                    : Text(
                        '${((order['total'] as num) / 1000).toStringAsFixed(3)} DT',
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OperationDetailScreen(
                      isSale: true,
                      operationId: id,
                      operation: order,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
