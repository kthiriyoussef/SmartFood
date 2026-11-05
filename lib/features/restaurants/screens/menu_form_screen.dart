import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/restaurants/models/menu.dart' as model;
import 'package:smartfood/features/restaurants/widgets/gradient_action_button.dart';

class MenuFormScreen extends StatelessWidget {
  const MenuFormScreen({
    super.key,
    required this.restaurantId,
    this.menu,
  });

  final int restaurantId;
  final model.Menu? menu;

  @override
  Widget build(BuildContext context) {
    final editing = menu != null;
    final available = menu?.disponible ?? true;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Fiche du plat' : 'Nouveau plat'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            _DishImagePlaceholder(),
            const SizedBox(height: 22),
            _FormSectionHeading(
              title: editing ? 'Détails du plat' : 'Composer votre plat',
              subtitle: 'Présentez votre spécialité avec soin.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: menu?.nom ?? '',
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom du plat',
                        hintText: 'Ex. Couscous du chef',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(menu?.categorie ?? 'Plats'),
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(menu?.categorie ?? 'Plats'),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: menu?.prix.toStringAsFixed(2) ?? '',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix',
                        hintText: '0,00',
                        prefixIcon: Icon(Icons.sell_outlined),
                        suffixText: 'DT',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: menu?.quantite.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantité en stock',
                        hintText: 'Ex. 20',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        suffixText: 'portions',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: menu?.description ?? '',
                      minLines: 3,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Ingrédients, accompagnements, préparation…',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 42),
                          child: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _FormSectionHeading(
              title: 'Disponibilité',
              subtitle: 'Indiquez si ce plat peut être commandé.',
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    _SoftIcon(
                      icon: available
                          ? Icons.check_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            available ? 'Disponible' : 'Rupture temporaire',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            available
                                ? 'Visible sur la carte du restaurant'
                                : 'Masqué jusqu’à son retour',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: available,
                      activeColor: AppColors.primary,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: GradientActionButton(
            label: editing ? 'Enregistrer le plat' : 'Ajouter à la carte',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
        'entrée' || 'entrées' => Icons.soup_kitchen_rounded,
        'dessert' || 'desserts' => Icons.cake_rounded,
        'boisson' || 'boissons' => Icons.local_bar_rounded,
        _ => Icons.dinner_dining_rounded,
      };
}

class _DishImagePlaceholder extends StatelessWidget {
  const _DishImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.activeBackground],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            bottom: -20,
            child: Icon(
              Icons.ramen_dining_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Ajouter une photo du plat',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Une belle image donne envie',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
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

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading({required this.title, required this.subtitle});

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

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}
