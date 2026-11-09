import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/reservations/widgets/note_analysis_badges.dart';

/// « Retrait client » : le restaurant scanne le QR ou tape le PIN,
/// l'application retrouve la réservation et valide la récupération.
/// C'est le SEUL moyen de passer une réservation au statut « Récupérée ».
class PickupValidationSheet extends StatefulWidget {
  const PickupValidationSheet({super.key, required this.restaurantId});

  final int restaurantId;

  static Future<void> show(BuildContext context, int restaurantId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => PickupValidationSheet(restaurantId: restaurantId),
    );
  }

  @override
  State<PickupValidationSheet> createState() => _PickupValidationSheetState();
}

class _PickupValidationSheetState extends State<PickupValidationSheet> {
  final _service = ReservationService();
  final _pinController = TextEditingController();

  bool _searching = false;
  bool _validating = false;
  String? _error;
  List<Reservation> _matches = const [];
  Reservation? _selected;
  Reservation? _done;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    setState(() {
      _searching = true;
      _error = null;
      _matches = const [];
      _selected = null;
    });
    final found = await _service.findByPickupCode(widget.restaurantId, code);
    if (!mounted) return;

    final ready =
        found.where((r) => r.status == ReservationStatus.prete).toList();
    String? error;
    if (found.isEmpty) {
      error = 'Aucune réservation ne correspond à ce code.';
    } else if (ready.isEmpty) {
      final r = found.first;
      error = r.status == ReservationStatus.recuperee
          ? '${r.reference} a déjà été récupérée.'
          : '${r.reference} n’est pas encore prête '
              '(statut : ${r.statusLabel}). Passez-la à « Prête » d’abord.';
    }
    setState(() {
      _searching = false;
      _error = error;
      _matches = ready;
      _selected = ready.length == 1 ? ready.first : null;
    });
  }

  Future<void> _scan() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _ScannerDialog(),
    );
    if (value != null && mounted) _lookup(value);
  }

  Future<void> _validate(Reservation reservation) async {
    setState(() => _validating = true);
    try {
      final updated =
          await _service.confirmPickup(reservation, reservation.pinCode);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _done = updated);
    } on ReservationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: _done != null
            ? _SuccessView(
                reservation: _done!,
                onClose: () => Navigator.of(context).pop(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Retrait client',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scannez le QR du client ou saisissez son code PIN.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _searching ? null : _scan,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scanner le QR code'),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ou'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      labelText: 'Code PIN',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    // Recherche automatique dès que les 4 chiffres sont tapés.
                    onChanged: (v) {
                      if (v.length == 4) _lookup(v);
                    },
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.archivedBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_matches.length > 1 && _selected == null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Plusieurs réservations ont ce PIN, choisissez :',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final r in _matches)
                      ListTile(
                        title: Text(r.clientName),
                        subtitle: Text('${r.dishNames} · ${r.reference}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => _selected = r),
                      ),
                  ],
                  if (_selected != null) ...[
                    const SizedBox(height: 14),
                    _ReservationSummary(reservation: _selected!),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed:
                          _validating ? null : () => _validate(_selected!),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: AppColors.primary,
                      ),
                      icon: _validating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('Valider le retrait'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ReservationSummary extends StatelessWidget {
  const _ReservationSummary({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reservation.clientName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text('${reservation.dishNames} · ${reservation.reference}'),
          Text('Retrait prévu : ${reservation.pickupTime}'),
          if (reservation.note != null) ...[
            Text('Note : ${reservation.note}'),
            const SizedBox(height: 6),
            NoteAnalysisBadges(reservation: reservation),
          ],
          const SizedBox(height: 8),
          Text(
            'À encaisser : ${reservation.total.toStringAsFixed(2)} DT',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.reservation, required this.onClose});

  final Reservation reservation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.primary, size: 72),
        const SizedBox(height: 10),
        Text(
          'Retrait validé',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${reservation.clientName} · ${reservation.dishNames}\n'
          '${reservation.total.toStringAsFixed(2)} DT encaissés',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}

class _ScannerDialog extends StatefulWidget {
  const _ScannerDialog();

  @override
  State<_ScannerDialog> createState() => _ScannerDialogState();
}

class _ScannerDialogState extends State<_ScannerDialog> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanner le QR du client'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              final value = capture.barcodes.firstOrNull?.rawValue?.trim();
              if (value == null || value.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(value);
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
