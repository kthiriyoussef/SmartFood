import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/utils/phone_call.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';

class RestaurantReservationDetailScreen extends StatefulWidget {
  const RestaurantReservationDetailScreen({
    super.key,
    required this.reservation,
  });

  final Reservation reservation;

  @override
  State<RestaurantReservationDetailScreen> createState() =>
      _RestaurantReservationDetailScreenState();
}

class _RestaurantReservationDetailScreenState
    extends State<RestaurantReservationDetailScreen> {
  late Reservation _reservation;
  final TextEditingController _pinController = TextEditingController();
  bool _showPinError = false;
  String? _feedbackMessage;

  static const List<String> _statusFlow = ReservationStatus.flow;
  final _service = ReservationService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  bool get _isCancelled => _reservation.status == ReservationStatus.annulee;
  bool get _isRecovered => _reservation.status == ReservationStatus.recuperee;
  bool get _canUseRecoveryValidation => !_isCancelled && !_isRecovered;

  /// Fait avancer le statut (enregistré en base).
  Future<void> _applyStatus(String status) async {
    await _run(
      () => _service.advanceStatus(_reservation, status),
      'Statut mis à jour : ${ReservationStatus.label(status)}',
    );
  }

  /// Valide le retrait avec un PIN saisi ou le contenu d'un QR scanné.
  Future<void> _confirmPickup(String code, String successMessage) async {
    final ok = await _run(
      () => _service.confirmPickup(_reservation, code),
      successMessage,
    );
    if (ok) _pinController.clear();
  }

  Future<bool> _run(
    Future<Reservation> Function() action,
    String successMessage,
  ) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return true;
      setState(() {
        _reservation = updated;
        _showPinError = false;
        _feedbackMessage = successMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } on ReservationException catch (e) {
      if (mounted) {
        setState(() {
          _showPinError = true;
          _feedbackMessage = e.message;
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Refus (en attente) ou annulation (plus tard) par le restaurant :
  /// les portions sont remises en stock.
  Future<void> _refuse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette réservation ?'),
        content: Text(
          '${_reservation.clientName} sera informé(e) dans son espace. '
          '${_reservation.quantity} portion(s) de « ${_reservation.dishName} » '
          'seront remises en stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _service.cancelByRestaurant(_reservation),
      'Réservation annulée, stock mis à jour',
    );
  }

  void _validatePinCode() {
    final enteredValue = _pinController.text.trim();
    if (enteredValue.isEmpty) {
      setState(() {
        _showPinError = true;
        _feedbackMessage = 'Saisissez le code PIN du client.';
      });
      return;
    }
    _confirmPickup(
        enteredValue, 'Réservation validée : récupération confirmée');
  }

  Future<void> _openQrScannerDialog() async {
    final controller = MobileScannerController();
    var scanned = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Scanner le QR code du client'),
          content: SizedBox(
            width: 320,
            height: 420,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (scanned || capture.barcodes.isEmpty) {
                  return;
                }

                final value = capture.barcodes.first.rawValue?.trim();
                if (value == null || value.isEmpty) {
                  scanned = true;
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _showPinError = true;
                    _feedbackMessage = 'QR code invalide. Réessayez.';
                  });
                  return;
                }

                scanned = true;
                Navigator.of(dialogContext).pop();
                _validateQrValue(value);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  void _validateQrValue(String value) {
    _confirmPickup(value, 'QR validé : commande récupérée');
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = _reservation.restaurantName;
    final dishNames =
        '${_reservation.dishNames} · ${_reservation.total.toStringAsFixed(2)} DT';
    final importantNote = _reservation.note == null
        ? 'Aucune note du client.'
        : 'Note du client : « ${_reservation.note} »';

    final statusSteps = [
      for (final step in _statusFlow)
        _StatusStep(
          title: ReservationStatus.label(step),
          isDone: !_isCancelled &&
              _statusFlow.indexOf(_reservation.status) >=
                  _statusFlow.indexOf(step),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Suivi réservation'),
        actions: [
          if (_reservation.status == ReservationStatus.enAttente)
            IconButton(
              tooltip: 'Appeler le client',
              onPressed: () => callPhone(context, _reservation.phoneNumber),
              icon: const Icon(Icons.phone_rounded),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F8F2),
              Color(0xFFF9F9F7),
              Color(0xFFF3F3F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF102A12),
                        Color(0xFF1C4E25),
                        Color(0xFF2E7032),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 22,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Réservation ${_reservation.reference}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.76),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Client',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _reservation.clientName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(_reservation.status),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _detailRow(context, Icons.store_mall_directory_outlined,
                          restaurantName),
                      const SizedBox(height: 10),
                      _detailRow(
                          context, Icons.restaurant_menu_rounded, dishNames),
                      const SizedBox(height: 10),
                      _detailRow(context, Icons.access_time_outlined,
                          _reservation.pickupTime),
                      const SizedBox(height: 10),
                      _detailRow(
                        context,
                        Icons.phone_outlined,
                        _reservation.phoneNumber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Note importante',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        importantNote,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.text,
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progression',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ...statusSteps.asMap().entries.map((entry) {
                              final index = entry.key;
                              final step = entry.value;
                              final isLast = index == statusSteps.length - 1;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: step.isDone
                                              ? AppColors.primary
                                              : Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: step.isDone
                                            ? const Icon(Icons.check,
                                                size: 12, color: Colors.white)
                                            : null,
                                      ),
                                      if (!isLast)
                                        Container(
                                          width: 2,
                                          height: 24,
                                          color: Colors.grey.shade300,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          top: 2, bottom: isLast ? 0 : 12),
                                      child: Text(
                                        step.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: step.isDone
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: step.isDone
                                                  ? AppColors.text
                                                  : AppColors.muted,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 118,
                        child: _StatusModifierPanel(
                          statusFlow: _statusFlow,
                          currentStatus: _reservation.status,
                          onStatusChanged: (status) {
                            if (_busy || _isCancelled) return;
                            if (status == ReservationStatus.recuperee) {
                              _showPinError = false;
                              _feedbackMessage =
                                  'Utilisez le formulaire de validation ci-dessous.';
                              setState(() {});
                              return;
                            }

                            if (status != _reservation.status) {
                              _applyStatus(status);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_canUseRecoveryValidation &&
                    !_isRecovered &&
                    !_isCancelled) ...[
                  const SizedBox(height: 18),
                  if (_reservation.status == ReservationStatus.prete)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Validation finale de récupération',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _ValidationMethodCard(
                                  title: 'Scanner QR',
                                  subtitle:
                                      'Le client montre le code QR de sa commande',
                                  icon: Icons.qr_code_scanner_rounded,
                                  onTap: _openQrScannerDialog,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ValidationMethodCard(
                                  title: 'Code PIN',
                                  subtitle:
                                      'Le client donne le code PIN affiché',
                                  icon: Icons.lock_outline_rounded,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Saisir le code PIN',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: InputDecoration(
                              labelText: 'Code PIN du client',
                              hintText: 'Ex : 8492',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              errorText: _showPinError ? 'Code invalide' : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: AppColors.background,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_feedbackMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _showPinError
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _feedbackMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _showPinError
                                          ? AppColors.error
                                          : Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _validatePinCode,
                              icon: const Icon(Icons.verified_rounded),
                              label: const Text('Valider la récupération'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else if (_isRecovered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Récupération validée — le client a bien récupéré sa commande.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_outlined,
                            color: AppColors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Réservation annulée.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (_reservation.status == ReservationStatus.enAttente)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Réservation à confirmer',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Un doute (quantité, heure, note) ? Appelez '
                          '${_reservation.clientFirstName} au '
                          '${_reservation.phoneNumber} avant de confirmer.',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => callPhone(
                                  context,
                                  _reservation.phoneNumber,
                                ),
                                icon: const Icon(Icons.phone_rounded),
                                label: const Text('Appeler'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _applyStatus(
                                          ReservationStatus.confirmee,
                                        ),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Confirmer'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (_reservation.isActive) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _refuse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.block_rounded),
                    label: Text(
                      _reservation.status == ReservationStatus.enAttente
                          ? 'Refuser la réservation'
                          : 'Annuler la réservation',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.82)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) => ReservationStatus.label(status);
}

class _StatusStep {
  const _StatusStep({required this.title, required this.isDone});

  final String title;
  final bool isDone;
}

class _StatusModifierPanel extends StatelessWidget {
  const _StatusModifierPanel({
    required this.statusFlow,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final List<String> statusFlow;
  final String currentStatus;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: statusFlow.map((status) {
        final isCurrent = status == currentStatus;
        // Tous les statuts non finaux sont accessibles (avancer ou corriger)
        // tant que la réservation est en cours. « Récupérée » : PIN / QR.
        final isActive = ReservationStatus.active.contains(currentStatus) &&
            !isCurrent &&
            status != ReservationStatus.recuperee;
        final isFinal = status == ReservationStatus.recuperee;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextButton(
            onPressed: isActive ||
                    (isFinal && currentStatus == ReservationStatus.prete)
                ? () => onStatusChanged(status)
                : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              backgroundColor: isCurrent
                  ? AppColors.primary
                  : (isActive ||
                          (isFinal && currentStatus == ReservationStatus.prete))
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.shade200,
              foregroundColor: isCurrent ? Colors.white : AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _statusLabel(status),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? Colors.white : null,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _statusLabel(String status) => ReservationStatus.label(status);
}

class _ValidationMethodCard extends StatelessWidget {
  const _ValidationMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
