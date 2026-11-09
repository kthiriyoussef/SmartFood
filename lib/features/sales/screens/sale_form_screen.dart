import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../models/sale.dart';
import '../models/dish.dart';
import '../repositories/sale_repository.dart';
import '../repositories/dish_repository.dart';

import 'package:smartfood/features/restaurants/screens/restaurant/menu_list_screen.dart';

import '../services/sale_service.dart';
import 'payment_screen.dart';

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key, required this.restaurantId, this.sale});
  final int restaurantId;
  final Sale? sale;
  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _repository = SaleRepository();
  final _dishRepository = DishRepository();
  late final List<_LineInput> _lines;
  List<Map<String, Object?>> _restaurants = [];
  List<Dish> _dishes = [];
  int? _restaurantId;
  late DateTime _date;
  bool _loading = true, _saving = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.sale;
    _restaurantId = initial?.restaurantId ?? widget.restaurantId;
    _date = initial?.date ?? DateTime.now();
    _lines = initial == null
        ? [_LineInput()]
        : initial.lines
              .map(
                (line) => _LineInput(
                  name: line.designation,
                  quantity: line.quantity.toString(),
                  price: (line.unitPrice / 1000).toStringAsFixed(3),
                  dishId: line.dishId,
                ),
              )
              .toList();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await (await DatabaseHelper.instance.database).query(
        'restaurants',
        where: 'id = ?',
        whereArgs: [widget.restaurantId],
      );
      if (!mounted) return;
      setState(() {
        _restaurants = db;
        _loading = false;
      });
      if (_restaurantId != null) await _loadDishes(_restaurantId!);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDishes(int restaurantId) async {
    try {
      final dishes = await _dishRepository.forRestaurant(
        restaurantId,
        availableOnly: widget.sale == null,
      );
      if (mounted) setState(() => _dishes = dishes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de charger les plats : $e')),
        );
      }
    }
  }

  int get _subtotal => _lines.fold(
    0,
    (sum, l) =>
        sum +
        ((double.tryParse(l.quantity.text.replaceAll(',', '.')) ?? 0) *
                ((double.tryParse(l.price.text.replaceAll(',', '.')) ?? 0) *
                    1000))
            .round(),
  );
  int get _discount => _subtotal >= 50000 ? (_subtotal * 10 / 100).round() : 0;
  int get _total => _subtotal - _discount;
  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sale == null ? 'Nouvelle vente' : 'Modifier la vente',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Restaurant'),
            initialValue: _restaurantId,
            items: _restaurants
                .map(
                  (r) => DropdownMenuItem(
                    value: r['id'] as int,
                    child: Text(r['nom'].toString()),
                  ),
                )
                .toList(),
            onChanged: null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de vente'),
            subtitle: Text(
              '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: _chooseDate,
          ),
          const SizedBox(height: 16),
          if (_restaurantId != null && _dishes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Aucun plat disponible pour ce restaurant.'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MenuListScreen(
                              restaurantId: widget.restaurantId,
                            ),
                          ),
                        );
                        if (mounted && _restaurantId != null) {
                          _loadDishes(_restaurantId!);
                        }
                      },
                      child: const Text('Ajouter des plats'),
                    ),
                  ],
                ),
              ),
            ),
          Text('Articles', style: Theme.of(context).textTheme.titleMedium),
          ..._lines.asMap().entries.map(
            (entry) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: entry.value.dishId,
                      decoration: const InputDecoration(
                        labelText: 'Choisir un plat',
                      ),
                      items: _dishes
                          .where(
                            (dish) =>
                                dish.available || dish.id == entry.value.dishId,
                          )
                          .map(
                            (dish) => DropdownMenuItem(
                              value: dish.id,
                              child: Text(
                                '${dish.name} • ${(dish.price / 1000).toStringAsFixed(3)} DT',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final dish = _dishes
                            .where((candidate) => candidate.id == id)
                            .firstOrNull;
                        if (dish == null) return;
                        setState(() {
                          entry.value.dishId = dish.id;
                          entry.value.name.text = dish.name;
                          entry.value.price.text = (dish.price / 1000)
                              .toStringAsFixed(3);
                        });
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entry.value.quantity,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: entry.value.price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prix du plat (DT)',
                            ),
                            readOnly: true,
                          ),
                        ),
                        IconButton(
                          onPressed: _lines.length == 1
                              ? null
                              : () => setState(() {
                                  _lines.removeAt(entry.key).dispose();
                                }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _lines.add(_LineInput())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un article'),
          ),
          const SizedBox(height: 12),
          Text('Sous-total : ${(_subtotal / 1000).toStringAsFixed(3)} DT'),
          if (_discount > 0)
            Text(
              'Remise (10 %) : -${(_discount / 1000).toStringAsFixed(3)} DT',
            ),
          Text(
            'À payer : ${(_total / 1000).toStringAsFixed(3)} DT',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Enregistrement…'
                  : widget.sale == null
                  ? 'Enregistrer la vente'
                  : 'Enregistrer les modifications',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sale = Sale(
        restaurantId: _restaurantId ?? 0,
        id: widget.sale?.id,
        date: _date,
        lines: _lines
            .map(
              (l) => SaleLine(
                designation: l.name.text,
                dishId: l.dishId,
                quantity:
                    double.tryParse(l.quantity.text.replaceAll(',', '.')) ?? 0,
                unitPrice:
                    ((double.tryParse(l.price.text.replaceAll(',', '.')) ??
                                -1) *
                            1000)
                        .round(),
              ),
            )
            .toList(),
      );
      SaleService.validate(sale);
      if (widget.sale?.id case final id?) {
        await _repository.updatePending(id, sale);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final id = await _repository.create(sale);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            saleId: id,
            total: sale.total,
            restaurant: _restaurants
                .firstWhere((r) => r['id'] == sale.restaurantId)['nom']
                .toString(),
            subtotal: sale.subtotal,
            discount: sale.discount,
          ),
        ),
      );
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _date = date);
  }
}

class _LineInput {
  _LineInput({
    String name = '',
    String quantity = '1',
    String price = '',
    this.dishId,
  }) : name = TextEditingController(text: name),
       quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;
  int? dishId;
  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}
