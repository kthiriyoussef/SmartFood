import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/screens/client/reservation_form_client.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/services/menu_service.dart';

/// Détail d'un plat côté client : nom, catégorie, description, prix,
/// quantité restante et bouton de réservation.
class MenuDetailClientScreen extends StatefulWidget {
  const MenuDetailClientScreen({
    super.key,
    required this.menu,
    required this.restaurant,
  });

  final Menu menu;
  final Restaurant restaurant;

  @override
  State<MenuDetailClientScreen> createState() => _MenuDetailClientScreenState();
}

class _MenuDetailClientScreenState extends State<MenuDetailClientScreen> {
  late Menu _menu = widget.menu;

  bool get _reservable =>
      ReservationService.isMenuReservable(_menu, widget.restaurant);

  /// Relit le plat en base (stock à jour après une réservation).
  Future<void> _refresh() async {
    final restaurantId = widget.restaurant.id;
    if (restaurantId == null) return;
    final menus = await MenuService().getMenusByRestaurant(restaurantId);
    final fresh = menus.where((m) => m.id == _menu.id);
    if (mounted && fresh.isNotEmpty) setState(() => _menu = fresh.first);
  }

  Future<void> _reserve() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservationFormScreen(
          menu: _menu,
          restaurant: widget.restaurant,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = _menu.quantite;
    final lowStock = _reservable && stock <= 5;
    final description = (_menu.description?.trim().isNotEmpty ?? false)
        ? _menu.description!.trim()
        : 'Aucune description pour ce plat.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(_menu.categorie),
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.activeBackground],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    margin: const EdgeInsets.only(top: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      categoryIcon(_menu.categorie),
                      size: 56,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _menu.nom,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatPrice(_menu.prix),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: categoryIcon(_menu.categorie),
                      label: _menu.categorie,
                      background: AppColors.warningBackground,
                      foreground: AppColors.secondary,
                    ),
                    _Pill(
                      icon: _reservable
                          ? Icons.inventory_2_outlined
                          : Icons.block_rounded,
                      label: !_reservable
                          ? 'Indisponible'
                          : lowStock
                              ? 'Plus que $stock portion${stock > 1 ? 's' : ''}'
                              : '$stock portions restantes',
                      background: !_reservable
                          ? AppColors.archivedBackground
                          : lowStock
                              ? AppColors.warningBackground
                              : AppColors.successBackground,
                      foreground: !_reservable
                          ? AppColors.error
                          : lowStock
                              ? AppColors.warning
                              : AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle('Description'),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Restaurant'),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.storefront_rounded,
                  title: widget.restaurant.nom,
                  subtitle:
                      '${widget.restaurant.adresse}, ${widget.restaurant.ville}',
                ),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.schedule_rounded,
                  title: 'Retrait sur place',
                  subtitle:
                      'Entre ${ReservationService.openingHour}h00 et ${ReservationService.closingHour}h00 · '
                      'prêt en ${ReservationService.preparationDelay.inMinutes} min minimum',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _reservable ? _reserve : null,
              icon: const Icon(Icons.event_available_rounded),
              label: Text(
                _reservable ? 'Réserver ce plat' : 'Plat indisponible',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatPrice(double price) =>
    '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} DT';

IconData categoryIcon(String category) => switch (category.toLowerCase()) {
      'entrée' || 'entree' => Icons.soup_kitchen_rounded,
      'dessert' => Icons.cake_rounded,
      'boisson' => Icons.local_bar_rounded,
      'menu complet' => Icons.lunch_dining_rounded,
      _ => Icons.dinner_dining_rounded,
    };

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.successBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
