import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../models/purchase.dart';
import '../repositories/purchase_repository.dart';
import '../services/purchase_service.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key, required this.restaurantId});
  final int restaurantId;
  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _lines = <_PurchaseLineInput>[_PurchaseLineInput()];
  List<Map<String, Object?>> _restaurants = [], _suppliers = [];
  int? _restaurant, _supplier;
  DateTime _date = DateTime.now();
  DateTime _delivery = DateTime.now().add(const Duration(days: 1));
  bool _loading = true, _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurantId;
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final r = await db.query(
        'restaurants',
        where: 'id = ?',
        whereArgs: [widget.restaurantId],
      );
      final s = await db.query('fournisseurs');
      if (mounted) {
        setState(() {
          _restaurants = r;
          _suppliers = s;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nouvel achat')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(child: Text('Erreur de chargement : $_loadError'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _supplier,
                decoration: const InputDecoration(labelText: 'Fournisseur'),
                items: _suppliers
                    .map(
                      (x) => DropdownMenuItem(
                        value: x['id'] as int,
                        child: Text(x['nom'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _supplier = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _restaurant,
                decoration: const InputDecoration(
                  labelText: 'Restaurant destinataire',
                ),
                items: _restaurants
                    .map(
                      (x) => DropdownMenuItem(
                        value: x['id'] as int,
                        child: Text(x['nom'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: null,
              ),
              _dateTile(
                'Date d’achat',
                _date,
                (value) => setState(() => _date = value),
              ),
              _dateTile(
                'Livraison prévue',
                _delivery,
                (value) => setState(() => _delivery = value),
              ),
              const SizedBox(height: 12),
              Text('Produits', style: Theme.of(context).textTheme.titleMedium),
              ..._lines.asMap().entries.map(
                (entry) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: entry.value.name,
                          decoration: const InputDecoration(
                            labelText: 'Désignation',
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.value.quantity,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantité',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: entry.value.unit,
                                decoration: const InputDecoration(
                                  labelText: 'Unité',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _lines.length == 1
                                  ? null
                                  : () => setState(
                                      () =>
                                          _lines.removeAt(entry.key).dispose(),
                                    ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        TextField(
                          controller: entry.value.price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Prix unitaire (DT)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _lines.add(_PurchaseLineInput())),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un produit'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? 'Enregistrement…' : 'Enregistrer l’achat',
                ),
              ),
            ],
          ),
  );

  Widget _dateTile(
    String title,
    DateTime date,
    ValueChanged<DateTime> onChange,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
    ),
    trailing: const Icon(Icons.calendar_month),
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (selected != null && mounted) onChange(selected);
    },
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final purchase = Purchase(
      supplierId: _supplier ?? 0,
      restaurantId: _restaurant ?? 0,
      date: _date,
      expectedDate: _delivery,
      lines: _lines
          .map(
            (line) => PurchaseLine(
              designation: line.name.text,
              quantity:
                  double.tryParse(line.quantity.text.replaceAll(',', '.')) ?? 0,
              unit: line.unit.text,
              unitPrice:
                  ((double.tryParse(line.price.text.replaceAll(',', '.')) ??
                              -1) *
                          1000)
                      .round(),
            ),
          )
          .toList(),
    );
    try {
      PurchaseService.validate(purchase);
      await PurchaseRepository().create(purchase);
      if (mounted) Navigator.pop(context);
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
}

class _PurchaseLineInput {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unit = TextEditingController(text: 'pièce');
  final price = TextEditingController();
  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    price.dispose();
  }
}
