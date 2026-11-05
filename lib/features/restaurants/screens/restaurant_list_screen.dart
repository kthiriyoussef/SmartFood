import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant_detail_screen.dart';
import 'package:smartfood/features/restaurants/screens/restaurant_form_screen.dart';
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';
import 'package:smartfood/features/restaurants/widgets/restaurant_status_badge.dart';

enum RestaurantListPreviewState { content, empty, loading, error }

class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({
    super.key,
    this.previewState = RestaurantListPreviewState.content,
  });

  final RestaurantListPreviewState previewState;

  static final List<Restaurant> _restaurants = [
    Restaurant(
      id: 1,
      nom: 'Le Jardin Gourmand',
      adresse: 'Les Berges du Lac',
      ville: 'Tunis',
      telephone: '+216 71 123 456',
      statut: RestaurantStatus.actif,
      dateCreation: DateTime(2024, 3, 12),
    ),
    Restaurant(
      id: 2,
      nom: 'Café des Oliviers',
      adresse: 'Centre-ville',
      ville: 'Sousse',
      telephone: '+216 73 456 789',
      statut: RestaurantStatus.actif,
      dateCreation: DateTime(2024, 6, 8),
    ),
    Restaurant(
      id: 3,
      nom: 'La Table du Marché',
      adresse: 'El Menzah 6',
      ville: 'Tunis',
      telephone: '+216 71 987 654',
      statut: RestaurantStatus.archive,
      dateCreation: DateTime(2023, 11, 21),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ListHeading(
                        onAdd: () => _openForm(context),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SearchAndFilter(
                        onFilter: () {},
                        onSort: () {},
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: _OverviewRow(
                        count: previewState == RestaurantListPreviewState.content
                            ? _restaurants.length
                            : 0,
                      ),
                    ),
                  ),
                  _buildRestaurantContent(context),
                ],
              ),
            ),
            const _ManagementBottomNavigation(),
          ],
        ),
      ),
      floatingActionButton: GradientActionButton(
        onPressed: () => _openForm(context),
        height: 56,
        icon: Icons.add_rounded,
        label: 'Ajouter',
      ),
    );
  }

  Widget _buildRestaurantContent(BuildContext context) {
    switch (previewState) {
      case RestaurantListPreviewState.loading:
        return const _LoadingCards();
      case RestaurantListPreviewState.error:
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(),
        );
      case RestaurantListPreviewState.empty:
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(),
        );
      case RestaurantListPreviewState.content:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
          sliver: SliverList.separated(
            itemCount: _restaurants.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final restaurant = _restaurants[index];
              return _RestaurantPreviewCard(
                restaurant: restaurant,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RestaurantDetailScreen(restaurant: restaurant),
                  ),
                ),
              );
            },
          ),
        );
    }
  }

  static void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RestaurantFormScreen()),
    );
  }
}

class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos établissements',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Retrouvez vos restaurants et leur activité en un coup d’œil.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        GradientActionButton(
          onPressed: onAdd,
          expand: true,
          icon: Icons.add_business_rounded,
          label: 'Ajouter un restaurant',
        ),
      ],
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({required this.onFilter, required this.onSort});

  final VoidCallback onFilter;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher un restaurant',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.tune_rounded,
          label: 'Filtrer',
          onPressed: onFilter,
        ),
        const SizedBox(width: 6),
        _HeaderIconButton(
          icon: Icons.swap_vert_rounded,
          label: 'Trier',
          onPressed: onSort,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.activeBackground.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Restaurants',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count établissements',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RestaurantPreviewCard extends StatelessWidget {
  const _RestaurantPreviewCard({
    required this.restaurant,
    required this.onTap,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = restaurant.statut == RestaurantStatus.actif;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: active
                        ? [
                            AppColors.activeBackground.withOpacity(0.7),
                            AppColors.activeBackground.withOpacity(0.25),
                          ]
                        : [
                            AppColors.inactiveBackground,
                            AppColors.inactiveBackground.withOpacity(0.55),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 30,
                  color: active ? AppColors.primary : AppColors.muted,
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${restaurant.adresse}, ${restaurant.ville}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RestaurantStatusBadge(status: restaurant.statut),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverList.separated(
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) => const _SkeletonRestaurantCard(),
      ),
    );
  }
}

class _SkeletonRestaurantCard extends StatelessWidget {
  const _SkeletonRestaurantCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SkeletonBlock(width: 62, height: 62, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBlock(width: 165, height: 16, radius: 6),
                  SizedBox(height: 10),
                  _SkeletonBlock(width: 205, height: 12, radius: 6),
                  SizedBox(height: 10),
                  _SkeletonBlock(width: 68, height: 22, radius: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.inactiveBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.activeBackground.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppColors.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun restaurant pour le moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre premier établissement pour commencer à organiser vos menus.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.error,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              'Impossible d’afficher les restaurants',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Réessayez dans quelques instants.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementBottomNavigation extends StatelessWidget {
  const _ManagementBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 1,
      onDestinationSelected: (index) {},
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront_rounded),
          label: 'Gestion',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}
