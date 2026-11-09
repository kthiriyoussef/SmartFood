import 'package:flutter/material.dart';

import '../repositories/sale_repository.dart';
import '../services/sale_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.saleId,
    required this.total,
    required this.restaurant,
    this.subtotal,
    this.discount = 0,
  });
  final int saleId, total;
  final int? subtotal;
  final int discount;
  final String restaurant;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _received = TextEditingController();
  String _mode = 'especes';
  bool _saving = false;
  int get _amount =>
      ((double.tryParse(_received.text.replaceAll(',', '.')) ?? 0) * 1000)
          .round();
  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Paiement')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.discount > 0) ...[
          Text(
            'Sous-total : ${((widget.subtotal ?? widget.total) / 1000).toStringAsFixed(3)} DT',
          ),
          Text(
            'Remise (10 %) : -${(widget.discount / 1000).toStringAsFixed(3)} DT',
          ),
        ],
        Text('Montant à payer', style: Theme.of(context).textTheme.titleMedium),
        Text(
          '${(widget.total / 1000).toStringAsFixed(3)} DT',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Mode de paiement'),
          items: const [
            DropdownMenuItem(value: 'especes', child: Text('Espèces')),
            DropdownMenuItem(value: 'carte', child: Text('Carte')),
            DropdownMenuItem(value: 'autre', child: Text('Autre')),
          ],
          onChanged: (v) => setState(() => _mode = v ?? 'especes'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _received,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montant reçu (DT)'),
        ),
        const SizedBox(height: 12),
        Text(
          'Monnaie à rendre : ${((_amount - widget.total).clamp(0, 999999999) / 1000).toStringAsFixed(3)} DT',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _pay,
          child: Text(_saving ? 'Validation…' : 'Valider le paiement'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
  Future<void> _pay() async {
    final amount = _mode == 'especes' ? _amount : widget.total;
    try {
      SaleService.changePayment(
        total: widget.total,
        mode: _mode,
        received: amount,
      );
      setState(() => _saving = true);
      await SaleRepository().pay(widget.saleId, _mode, amount);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentConfirmationScreen(
            saleId: widget.saleId,
            total: widget.total,
            restaurant: widget.restaurant,
            mode: _mode,
            change: _mode == 'especes' ? amount - widget.total : 0,
            subtotal: widget.subtotal,
            discount: widget.discount,
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
}

class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({
    super.key,
    required this.saleId,
    required this.total,
    required this.restaurant,
    required this.mode,
    required this.change,
    this.subtotal,
    this.discount = 0,
  });
  final int saleId, total, change;
  final int? subtotal;
  final int discount;
  final String restaurant, mode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmation')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            Text(
              'Paiement confirmé',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Référence : #$saleId\nRestaurant : $restaurant\nMode : $mode\n${discount > 0 ? 'Sous-total : ${((subtotal ?? total) / 1000).toStringAsFixed(3)} DT\nRemise : -${(discount / 1000).toStringAsFixed(3)} DT\n' : ''}Monnaie rendue : ${(change / 1000).toStringAsFixed(3)} DT\nTotal payé : ${(total / 1000).toStringAsFixed(3)} DT',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Voir le reçu'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Nouvelle vente'),
            ),
          ],
        ),
      ),
    ),
  );
}
