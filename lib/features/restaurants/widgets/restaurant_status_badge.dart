import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';

class RestaurantStatusBadge extends StatelessWidget {
  const RestaurantStatusBadge({super.key, required this.status});

  final RestaurantStatus status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == RestaurantStatus.actif;
    final foreground = isActive ? AppColors.primary : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [AppColors.activeBackground, AppColors.successBackground]
              : [AppColors.errorLight, AppColors.archivedBackground],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: foreground,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Actif' : 'Archivé',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
