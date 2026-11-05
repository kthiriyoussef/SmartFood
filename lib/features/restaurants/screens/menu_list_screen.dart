import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/menu_form_screen.dart';
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';
import 'package:smartfood/features/restaurants/widgets/menu_availability_badge.dart';

enum MenuListPreviewState { content, empty, loading, error }

class MenuListScreen extends StatelessWidget {
  const MenuListScreen({
    super.key,
    required this.restaurant,
    this.previewState = MenuListPreviewState.content,
  });

  final Restaurant restaurant;
  final MenuListPreviewState previewState;

  static final List<Menu> _dishes = [
    Menu(
      id: 1,
      restaurantId: 1,
      nom: 'Brik à l’œuf',
      description: 'Thon, câpres et œuf frais',
      prix: 8.5,
      categorie: 'Entrées',
      quantite: 14,
      disponible: true,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 2,
      restaurantId: 1,
      nom: 'Couscous du chef',
      description: 'Légumes de saison et agneau fondant',
      prix: 26,
      categorie: 'Plats',
      quantite: 8,
      disponible: true,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 3,
      restaurantId: 1,
      nom: 'Assiette de pâtisseries',
      description: 'Sélection maison, selon arrivage',
      prix: 12,
      categorie: 'Desserts',
      quantite: 0,
      disponible: false,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 4,
      restaurantId: 1,
      nom: 'Citronnade fraîche',
      description: 'Citron pressé et menthe fraîche',
      prix: 6,
      categorie: 'Boissons',
      quantite: 20,
      disponible: true,
      dateCreation: DateTime(2025, 1, 12),
    ),
  ];

  static const _categories = [
    ('Entrées', Icons.soup_kitchen_rounded),
    ('Plats', Icons.dinner_dining_rounded),
    ('Desserts', Icons.cake_rounded),
    ('Boissons', Icons.local_bar_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('La carte'),
        actions: [
          IconButton(
            tooltip: 'Plus d’options',
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            sliver: SliverToBoxAdapter(
              child: _RestaurantMenuBanner(restaurant: restaurant),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un plat',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
                  IconButton.filledTonal(
                    tooltip: 'Filtrer la carte',
                    onPressed: () {},
                    icon: const Icon(Icons.tune_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.successBackground,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 66,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = index == 0;
                  return Chip(
                    avatar: Icon(
                      category.$2,
                      size: 18,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                    label: Text(category.$1),
                    backgroundColor:
                        selected ? AppColors.primary : Colors.white,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : AppColors.text,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  );
                },
              ),
            ),
          ),
          if (previewState == MenuListPreviewState.content)
            ..._buildMenuSections(context)
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MenuPreviewState(state: previewState),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: GradientActionButton(
        label: 'Ajouter un plat',
        icon: Icons.add_rounded,
        height: 56,
        onPressed: () => _openDishForm(context),
      ),
    );
  }

  List<Widget> _buildMenuSections(BuildContext context) {
    return [
      for (final category in _categories)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          sliver: SliverToBoxAdapter(
            child: _DishCategorySection(
              name: category.$1,
              icon: category.$2,
              dishes: _dishes
                  .where((dish) => dish.categorie == category.$1)
                  .toList(),
              onDishTap: (dish) => _openDishForm(context, dish),
            ),
          ),
        ),
    ];
  }

  void _openDishForm(BuildContext context, [Menu? menu]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MenuFormScreen(
          restaurantId: restaurant.id ?? 1,
          menu: menu,
        ),
      ),
    );
  }
}

class _RestaurantMenuBanner extends StatelessWidget {
  const _RestaurantMenuBanner({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.activeBackground],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'La carte · ${restaurant.ville}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 25),
        ],
      ),
    );
  }
}

class _DishCategorySection extends StatelessWidget {
  const _DishCategorySection({
    required this.name,
    required this.icon,
    required this.dishes,
    required this.onDishTap,
  });

  final String name;
  final IconData icon;
  final List<Menu> dishes;
  final ValueChanged<Menu> onDishTap;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${dishes.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        for (final dish in dishes) ...[
          _DishCard(dish: dish, onTap: () => onDishTap(dish)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.onTap});

  final Menu dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.successBackground, AppColors.background],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.dinner_dining_rounded,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dish.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MenuAvailabilityBadge(available: dish.disponible),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.sell_outlined,
                    color: AppColors.primary,
                    size: 17,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dish.prix.toStringAsFixed(dish.prix % 1 == 0 ? 0 : 1)} DT',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPreviewState extends StatelessWidget {
  const _MenuPreviewState({required this.state});

  final MenuListPreviewState state;

  @override
  Widget build(BuildContext context) {
    if (state == MenuListPreviewState.loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _DishSkeleton(),
      );
    }

    final isError = state == MenuListPreviewState.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError
                  ? Icons.cloud_off_rounded
                  : Icons.menu_book_outlined,
              color: isError ? AppColors.error : AppColors.primary,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isError ? 'Carte indisponible' : 'Aucun plat pour ce restaurant',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isError
                  ? 'Réessayez dans un instant.'
                  : 'Ajoutez vos premières spécialités pour composer votre carte.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishSkeleton extends StatelessWidget {
  const _DishSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.inactiveBackground,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 140, height: 14),
                  SizedBox(height: 9),
                  _SkeletonLine(width: 190, height: 10),
                  SizedBox(height: 9),
                  _SkeletonLine(width: 82, height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.inactiveBackground,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
