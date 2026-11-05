import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart' as model;
import 'package:smartfood/features/restaurants/widgets/menu_availability_badge.dart';

class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.menu,
    this.onEdit,
    this.onDelete,
    this.onAvailabilityChanged,
  });

  final model.Menu menu;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.activeBackground.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.nom,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        menu.categorie,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      menu.prix.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'DT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (menu.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                menu.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                MenuAvailabilityBadge(available: menu.disponible),
                const SizedBox(width: 8),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: menu.quantite > 0 ? AppColors.muted : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '${menu.quantite} en stock',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: menu.quantite > 0
                            ? AppColors.muted
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (onAvailabilityChanged != null)
                  Tooltip(
                    message: menu.disponible
                        ? 'Rendre indisponible'
                        : 'Rendre disponible',
                    child: Switch.adaptive(
                      value: menu.disponible,
                      activeColor: AppColors.primary,
                      onChanged: onAvailabilityChanged,
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Modifier le menu',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Supprimer le menu',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
