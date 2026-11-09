import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../purchases/repositories/purchase_repository.dart';
import '../repositories/sale_repository.dart';
import 'sale_form_screen.dart';
import '../../purchases/screens/purchase_form_screen.dart';
import 'operation_detail_screen.dart';

import 'package:smartfood/features/restaurants/screens/restaurant/menu_list_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.restaurantId});
  final int restaurantId;
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });
  final _sales = SaleRepository();
  final _purchases = PurchaseRepository();
  Future<List<Map<String, Object?>>> _load(int index) => index == 0
      ? _sales.all(restaurantId: widget.restaurantId)
      : _purchases.all(restaurantId: widget.restaurantId);
  DateTime _reportStart = DateTime.now();
  DateTime _reportEnd = DateTime.now();
  Future<List<int>> _stats(int index) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    if (index == 0) {
      final summary = await _sales.salesSummary(
        widget.restaurantId,
        _reportStart,
        _reportEnd,
      );
      return [summary['total']!, summary['count']!, summary['average']!];
    }
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COALESCE(SUM(total),0) FROM achats WHERE restaurant_id=? AND substr(date_achat,1,7)=?",
            [widget.restaurantId, month],
          ),
        ) ??
        0;
    return [
      total,
      await _purchases.pendingCount(restaurantId: widget.restaurantId),
    ];
  }

  String _money(Object? raw) => '${((raw as num?) ?? 0) / 1000.0} DT';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ventes & achats'),
      actions: [
        IconButton(
          tooltip: 'Gérer les plats du restaurant',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MenuListScreen(restaurantId: widget.restaurantId),
              ),
            );
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.restaurant_menu),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Ventes'),
          Tab(text: 'Achats'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [0, 1].map((i) => _list(i)).toList(),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _newOperation(_tabs.index),
      icon: const Icon(Icons.add),
      label: Text(
        _tabs.index == 0 ? 'Enregistrer une vente' : 'Enregistrer un achat',
      ),
      backgroundColor: const Color(0xFFFB8C00),
    ),
  );

  Widget _list(int index) => FutureBuilder<List<Map<String, Object?>>>(
    future: _load(index),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Erreur de chargement : ${snapshot.error}'));
      }
      final records = snapshot.data ?? [];
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          await _load(index);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<int>>(
              future: _stats(index),
              builder: (context, stats) {
                if (stats.connectionState != ConnectionState.done ||
                    !stats.hasData) {
                  return const LinearProgressIndicator();
                }
                return _statsView(index, stats.data!);
              },
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: Text('Aucune opération pour le moment.')),
              ),
            ...records.map(
              (row) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(
                    index == 0
                        ? (row['restaurant']?.toString() ?? 'Vente')
                        : (row['fournisseur']?.toString() ?? 'Achat'),
                  ),
                  subtitle: Text(
                    row[index == 0 ? 'date_vente' : 'date_achat'].toString(),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(row['total'])),
                      _statusBadge(row['statut']?.toString() ?? ''),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OperationDetailScreen(
                          isSale: index == 0,
                          operationId: row['id']! as int,
                          operation: row,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _statsView(int index, List<int> stats) {
    if (index != 0) {
      return Row(
        children: [
          Expanded(child: _metric('Achats du mois', _money(stats[0]))),
          const SizedBox(width: 12),
          Expanded(child: _metric('À réceptionner', '${stats[1]}')),
        ],
      );
    }
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _chooseReportPeriod,
          icon: const Icon(Icons.date_range),
          label: Text(
            '${_dateLabel(_reportStart)} – ${_dateLabel(_reportEnd)}',
          ),
        ),
        Row(
          children: [
            Expanded(child: _metric('Total encaissé', _money(stats[0]))),
            const SizedBox(width: 8),
            Expanded(child: _metric('Ventes encaissées', '${stats[1]}')),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: _metric('Panier moyen', _money(stats[2])),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _chooseReportPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _reportStart.isAfter(_reportEnd) ? _reportEnd : _reportStart,
        end: _reportEnd,
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _reportStart = range.start;
        _reportEnd = range.end;
      });
    }
  }

  Widget _metric(String title, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'payee' => ('Payée', const Color(0xFF2E7D32)),
      'recu' => ('Reçu', const Color(0xFF2E7D32)),
      'annulee' || 'annule' => ('Annulée', const Color(0xFFD32F2F)),
      'en_attente' => ('En attente', const Color(0xFFFB8C00)),
      _ => (status, const Color(0xFF6B7280)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      ),
    );
  }

  Future<void> _newOperation(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => index == 0
            ? SaleFormScreen(restaurantId: widget.restaurantId)
            : PurchaseFormScreen(restaurantId: widget.restaurantId),
      ),
    );
    if (mounted) setState(() {});
  }
}
