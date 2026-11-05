import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant_form_screen.dart';
import 'package:smartfood/features/restaurants/screens/menu_list_screen.dart';
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';
import 'package:smartfood/features/restaurants/widgets/restaurant_status_badge.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  static final _previewMenus = [
    Menu(
      id: 1,
      restaurantId: 1,
      nom: 'Brunch du jardin',
      description: 'Assiette fraîche, pain maison et boisson chaude.',
      prix: 24,
      categorie: 'Menu complet',
      quantite: 12,
      disponible: true,
      dateCreation: DateTime(2025, 2, 10),
    ),
    Menu(
      id: 2,
      restaurantId: 1,
      nom: 'Bowl méditerranéen',
      description: 'Légumes de saison, céréales et sauce aux herbes.',
      prix: 18,
      categorie: 'Plat',
      quantite: 9,
      disponible: true,
      dateCreation: DateTime(2025, 2, 10),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isActive = restaurant.statut == RestaurantStatus.actif;
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            stretch: true,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primary,
            title: const Text('Restaurant'),
            flexibleSpace: FlexibleSpaceBar(
              background: _CoverHeader(restaurant: restaurant),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _SectionTitle(
                    title: 'Vue d’ensemble',
                    subtitle: 'Les chiffres clés de votre établissement',
                  ),
                  const SizedBox(height: 12),
                  const _QuickStats(),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Informations générales',
                    subtitle: 'Coordonnées et emplacement',
                  ),
                  const SizedBox(height: 12),
                  _InformationCard(restaurant: restaurant),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: GradientActionButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RestaurantFormScreen(restaurant: restaurant),
                            ),
                          ),
                          icon: Icons.edit_outlined,
                          label: 'Modifier',
                          expand: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isActive ? () {} : null,
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Archiver'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(
                          title: 'La carte du restaurant',
                          subtitle: 'Plats, prix et disponibilités',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MenuListScreen(restaurant: restaurant),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Tout voir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final menu in _previewMenus) ...[
                    _PreviewMenuTile(
                      menu: menu,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MenuListScreen(restaurant: restaurant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                addAutomaticKeepAlives: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.success,
                AppColors.activeBackground,
              ],
            ),
          ),
        ),
        Positioned(
          right: -32,
          top: 14,
          child: Icon(
            Icons.local_dining_rounded,
            size: 190,
            color: Colors.white.withOpacity(0.09),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 22,
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.17),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.adresse} · ${restaurant.ville}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RestaurantStatusBadge(status: restaurant.statut),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatCard(
            icon: Icons.restaurant_menu_rounded,
            value: '12',
            label: 'Menus',
            tint: AppColors.primary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.shopping_bag_outlined,
            value: '86',
            label: 'Commandes',
            tint: AppColors.secondary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            value: '4.8',
            label: 'Avis',
            tint: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: tint, size: 21),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            _InfoTile(
              icon: Icons.place_outlined,
              label: 'Adresse',
              value: '${restaurant.adresse}, ${restaurant.ville}',
            ),
            const Divider(height: 1, color: AppColors.border),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: restaurant.telephone,
            ),
            const Divider(height: 1, color: AppColors.border),
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Depuis le',
              value:
                  '${restaurant.dateCreation.day.toString().padLeft(2, '0')}/'
                  '${restaurant.dateCreation.month.toString().padLeft(2, '0')}/'
                  '${restaurant.dateCreation.year}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.activeBackground.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _PreviewMenuTile extends StatelessWidget {
  const _PreviewMenuTile({required this.menu, required this.onTap});

  final Menu menu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.activeBackground.withOpacity(0.32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.nom,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
            Text(
              '${menu.prix.toStringAsFixed(0)} DT',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
