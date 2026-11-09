import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../purchases/repositories/purchase_repository.dart';
import '../models/sale.dart';
import '../repositories/sale_repository.dart';
import 'sale_form_screen.dart';

class OperationDetailScreen extends StatefulWidget {
  const OperationDetailScreen({
    super.key,
    required this.isSale,
    required this.operationId,
    required this.operation,
  });
  final bool isSale;
  final int operationId;
  final Map<String, Object?> operation;
  @override
  State<OperationDetailScreen> createState() => _OperationDetailScreenState();
}

class _OperationDetailScreenState extends State<OperationDetailScreen> {
  late final Future<List<Map<String, Object?>>> _lines = _load();
  late String _status;
  bool _receiving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.operation['statut']?.toString() ?? '';
  }

  Future<List<Map<String, Object?>>> _load() async =>
      (await DatabaseHelper.instance.database).query(
        widget.isSale ? 'lignes_vente' : 'lignes_achat',
        where: widget.isSale ? 'vente_id = ?' : 'achat_id = ?',
        whereArgs: [widget.operationId],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isSale ? 'Détail de la vente' : 'Détail de l’achat'),
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _lines,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final row = widget.operation;
        final lines = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSale
                          ? 'Restaurant : ${row['restaurant']}'
                          : 'Fournisseur : ${row['fournisseur']}',
                    ),
                    if (!widget.isSale)
                      Text('Restaurant destinataire : ${row['restaurant']}'),
                    Text(
                      'Date : ${row[widget.isSale ? 'date_vente' : 'date_achat']}',
                    ),
                    Text('Statut : ${_statusLabel(_status)}'),
                    if (widget.isSale && row['sous_total'] != null)
                      Text('Sous-total : ${_money(row['sous_total'])}'),
                    if (widget.isSale && ((row['remise'] as num?) ?? 0) > 0)
                      Text(
                        'Remise (${row['taux_remise']} %) : -${_money(row['remise'])}',
                      ),
                    Text('Total : ${_money(row['total'])}'),
                    if (widget.isSale &&
                        row['statut'] == 'annulee' &&
                        row['motif_annulation'] != null)
                      Text('Motif d’annulation : ${row['motif_annulation']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isSale ? 'Articles' : 'Produits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (lines.isEmpty) const Text('Aucune ligne enregistrée.'),
            ...lines.map(
              (line) => ListTile(
                title: Text(line['designation'].toString()),
                subtitle: Text(
                  '${line['quantite']} ${widget.isSale ? '' : line['unite']} × ${((line['prix_unitaire']! as num) / 1000).toStringAsFixed(3)} DT',
                ),
                trailing: Text(
                  '${(((line['quantite']! as num) * (line['prix_unitaire']! as num)) / 1000).toStringAsFixed(3)} DT',
                ),
              ),
            ),
            if (widget.isSale && row['statut'] != 'annulee')
              OutlinedButton(
                onPressed: _cancelSale,
                child: const Text('Annuler la vente'),
              ),
            if (widget.isSale && row['statut'] == 'en_attente')
              FilledButton.tonal(
                onPressed: () => _editSale(lines),
                child: const Text('Modifier la vente'),
              ),
            if (!widget.isSale && _status == 'en_attente')
              FilledButton(
                onPressed: _receiving ? null : _receivePurchase,
                child: Text(
                  _receiving ? 'Enregistrement…' : 'Confirmer la réception',
                ),
              ),
          ],
        );
      },
    ),
  );

  Future<void> _editSale(List<Map<String, Object?>> rows) async {
    final row = widget.operation;
    final sale = Sale(
      id: widget.operationId,
      restaurantId: row['restaurant_id']! as int,
      date: DateTime.parse(row['date_vente']! as String),
      paymentMode: row['mode_paiement']! as String,
      amountReceived: row['montant_recu']! as int,
      status: row['statut']! as String,
      lines: rows
          .map(
            (line) => SaleLine(
              designation: line['designation']! as String,
              quantity: (line['quantite']! as num).toDouble(),
              unitPrice: line['prix_unitaire']! as int,
              dishId: line['menu_id'] as int?,
            ),
          )
          .toList(),
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SaleFormScreen(restaurantId: sale.restaurantId, sale: sale),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _cancelSale() async {
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final cancellationReason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler la vente ?'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('La vente annulée restera dans l’historique.'),
                TextFormField(
                  controller: reason,
                  autofocus: true,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Motif obligatoire',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Saisissez le motif de l’annulation.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, reason.text.trim());
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (cancellationReason == null || !mounted) return;
    try {
      await SaleRepository().cancel(widget.operationId, cancellationReason);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _money(Object? raw) =>
      '${(((raw as num?) ?? 0) / 1000).toStringAsFixed(3)} DT';

  String _statusLabel(String status) => switch (status) {
    'en_attente' => 'En attente',
    'recu' => 'Reçu',
    'payee' => 'Payée',
    'annulee' => 'Annulée',
    _ => status,
  };

  Future<void> _receivePurchase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la réception'),
        content: const Text('Marquer cet achat comme reçu ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _receiving = true);
    try {
      await PurchaseRepository().receive(widget.operationId);
      if (mounted) {
        setState(() {
          _status = 'recu';
          _receiving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Achat marqué comme reçu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _receiving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
