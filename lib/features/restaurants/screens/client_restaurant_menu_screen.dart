import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/widgets/menu_availability_badge.dart';

class ClientRestaurantMenuScreen extends StatefulWidget {
  const ClientRestaurantMenuScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<ClientRestaurantMenuScreen> createState() =>
      _ClientRestaurantMenuScreenState();
}

class _ClientRestaurantMenuScreenState
    extends State<ClientRestaurantMenuScreen> {
  static final List<Menu> _sampleMenus = [
    Menu(
      id: 1,
      restaurantId: 1,
      nom: 'Brik à l’œuf',
      description: 'Thon, câpres et œuf frais dans une feuille croustillante.',
      prix: 8.5,
      categorie: 'Entrée',
      quantite: 14,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 2,
      restaurantId: 1,
      nom: 'Couscous du chef',
      description: 'Légumes de saison et agneau mijoté aux épices.',
      prix: 26,
      categorie: 'Plat',
      quantite: 8,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 3,
      restaurantId: 1,
      nom: 'Bowl méditerranéen',
      description: 'Céréales, légumes frais et sauce aux herbes.',
      prix: 18,
      categorie: 'Plat',
      quantite: 6,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 4,
      restaurantId: 1,
      nom: 'Pâtisseries maison',
      description: 'Sélection du jour, préparée sur place.',
      prix: 12,
      categorie: 'Dessert',
      quantite: 0,
      disponible: false,
      dateCreation: DateTime(2025, 1, 12),
    ),
    Menu(
      id: 5,
      restaurantId: 1,
      nom: 'Citronnade à la menthe',
      description: 'Citron fraîchement pressé et menthe.',
      prix: 6,
      categorie: 'Boisson',
      quantite: 20,
      dateCreation: DateTime(2025, 1, 12),
    ),
  ];

  static const _categories = [
    ('Tout', Icons.restaurant_menu_rounded),
    ('Entrée', Icons.soup_kitchen_rounded),
    ('Plat', Icons.dinner_dining_rounded),
    ('Dessert', Icons.cake_rounded),
    ('Boisson', Icons.local_bar_rounded),
  ];

  final _searchController = TextEditingController();
  String _selectedCategory = 'Tout';
  String _query = '';

  Color _categoryColor(String category) => switch (category.toLowerCase()) {
        'entrée' || 'entree' || 'dessert' || 'boisson' => AppColors.secondary,
        _ => AppColors.primary,
      };

  List<Menu> get _visibleMenus {
    final query = _query.trim().toLowerCase();
    return _sampleMenus.where((menu) {
      final matchesCategory =
          _selectedCategory == 'Tout' || menu.categorie == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          menu.nom.toLowerCase().contains(query) ||
          (menu.description?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menus = _visibleMenus;
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 214,
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primary,
            title: const Text('Restaurant'),
            flexibleSpace: FlexibleSpaceBar(
              background: const _RestaurantCover(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.restaurant.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  const Icon(Icons.star_rounded, color: AppColors.secondary),
                  const SizedBox(width: 3),
                  Text(
                    '4.8',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.restaurant.adresse}, ${widget.restaurant.ville}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.circle,
                    size: 8,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Ouvert',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 0),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans la carte',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
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
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 11, 18, 7),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = category.$1 == _selectedCategory;
                  return ChoiceChip(
                    avatar: Icon(
                      category.$2,
                      size: 17,
                      color:
                          selected ? Colors.white : _categoryColor(category.$1),
                    ),
                    label: Text(category.$1),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category.$1),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    labelStyle:
                        Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: selected ? Colors.white : AppColors.text,
                            ),
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'La carte',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${menus.length} plats',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (menus.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Aucun plat dans cette catégorie.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: SliverList.separated(
                itemCount: menus.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ClientMenuCard(
                  menu: menus[index],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La commande sera bientôt disponible.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCover extends StatelessWidget {
  const _RestaurantCover();

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
              colors: [AppColors.primary, AppColors.activeBackground],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: -12,
          child: Icon(
            Icons.restaurant_rounded,
            size: 170,
            color: Colors.white.withOpacity(0.18),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 22,
          right: 20,
          child: Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Une cuisine à découvrir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.secondary,
                      size: 17,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '4.8',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientMenuCard extends StatelessWidget {
  const _ClientMenuCard({required this.menu});

  final Menu menu;

  @override
  Widget build(BuildContext context) {
    final available = menu.disponible && menu.quantite > 0;
    final lowStock = available && menu.quantite <= 5;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.warningBackground, AppColors.background],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(menu.categorie),
                color: _categoryColor(menu.categorie),
                size: 29,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    menu.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                  const SizedBox(height: 7),
                  if (!available)
                    const MenuAvailabilityBadge(available: false)
                  else if (lowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Plus que ${menu.quantite}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    )
                  else
                    const MenuAvailabilityBadge(available: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${menu.prix.toStringAsFixed(menu.prix % 1 == 0 ? 0 : 1)} DT',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
        'entrée' || 'entree' => Icons.soup_kitchen_rounded,
        'dessert' => Icons.cake_rounded,
        'boisson' => Icons.local_bar_rounded,
        _ => Icons.dinner_dining_rounded,
      };

  Color _categoryColor(String category) => switch (category.toLowerCase()) {
        'entrée' || 'entree' || 'dessert' || 'boisson' => AppColors.secondary,
        _ => AppColors.primary,
      };
}
