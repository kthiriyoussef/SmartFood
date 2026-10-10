import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation, this.onTap});

  final Reservation reservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(reservation.status);
    final restaurantName = reservation.restaurantName ?? 'Restaurant SmartFood';
    final dishNames = reservation.dishNames ?? 'Plat du jour';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Réf. ${reservation.id}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusMeta.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusMeta.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusMeta.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dishNames,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    reservation.pickupTime,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'PRETE':
        return _StatusMeta(
          label: 'Prête',
          background: AppColors.success.withValues(alpha: 0.12),
          foreground: AppColors.primary,
        );
      case 'RECUPEREE':
        return _StatusMeta(
          label: 'Récupérée',
          background: AppColors.success.withValues(alpha: 0.12),
          foreground: AppColors.primary,
        );
      case 'ANNULEE':
        return _StatusMeta(
          label: 'Annulée',
          background: AppColors.error.withValues(alpha: 0.12),
          foreground: AppColors.error,
        );
      case 'CONFIRMEE':
        return _StatusMeta(
          label: 'Confirmée',
          background: AppColors.warning.withValues(alpha: 0.16),
          foreground: AppColors.warning,
        );
      case 'PREPARATION':
        return _StatusMeta(
          label: 'Préparation',
          background: AppColors.warning.withValues(alpha: 0.16),
          foreground: AppColors.warning,
        );
      case 'EN_ATTENTE':
      default:
        return _StatusMeta(
          label: 'En attente',
          background: AppColors.warning.withValues(alpha: 0.14),
          foreground: AppColors.warning,
        );
    }
  }
}

class _StatusMeta {
  const _StatusMeta({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
