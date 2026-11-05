import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';

class MenuAvailabilityBadge extends StatelessWidget {
  const MenuAvailabilityBadge({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final foreground = available ? AppColors.primary : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: available
              ? [AppColors.activeBackground, AppColors.successBackground]
              : [AppColors.errorLight, AppColors.archivedBackground],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: foreground,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'Disponible' : 'Rupture',
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
