import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/client/menu_detail_client_screen.dart';
import 'package:smartfood/features/reservations/screens/client/reservation_details_client.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';

/// Affichée juste après la création : le client y retrouve sa référence,
/// son code PIN et le QR code à présenter au restaurant.
class ReservationConfirmationScreen extends StatelessWidget {
  const ReservationConfirmationScreen({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: AppColors.successBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Réservation enregistrée',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Le restaurant va la confirmer. Présentez ce QR code ou votre '
            'code PIN au moment du retrait.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: ReservationService.qrPayload(reservation),
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 14),
                Text(
                  'Réf. ${reservation.reference}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Code PIN', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  reservation.pinCode.split('').join(' '),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _Line(
                  icon: Icons.storefront_rounded,
                  label: 'Restaurant',
                  value: reservation.restaurantName,
                ),
                _Line(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Plat',
                  value: reservation.dishNames,
                ),
                _Line(
                  icon: Icons.schedule_rounded,
                  label: 'Retrait',
                  value: reservation.pickupTime,
                ),
                _Line(
                  icon: Icons.person_outline_rounded,
                  label: 'Au nom de',
                  value: reservation.clientName,
                ),
                _Line(
                  icon: Icons.payments_outlined,
                  label: 'À payer sur place',
                  value: formatPrice(reservation.total),
                  highlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Retour à la carte'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ReservationDetailScreen(reservation: reservation),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Suivre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
