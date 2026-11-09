import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/menu_form_screen.dart';
import 'package:smartfood/features/restaurants/services/menu_service.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

/// Gestion de la carte d'un restaurant.
class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  final _menuService = MenuService();
  final _restaurantService = RestaurantService();

  Restaurant? _restaurant;
  List<Menu> _menus = const [];
  bool _loading = true;
  String _category = 'Toutes';
  String _query = '';
  bool _onlyAlerts = false;

  bool get _archived => _restaurant?.statut == RestaurantStatus.archive;

  @override
  void initState() {
    super.initState();
    _load();
    DataChanges.catalog.addListener(_load);
  }

  @override
  void dispose() {
    DataChanges.catalog.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final restaurant =
        await _restaurantService.getRestaurantById(widget.restaurantId);
    final menus = await _menuService.getMenusByRestaurant(widget.restaurantId);
    if (!mounted) return;
    setState(() {
      _restaurant = restaurant;
      _menus = menus;
      _loading = false;
    });
  }

  bool _isAlert(Menu m) =>
      !m.disponible || m.quantite <= MenuService.seuilStockBas;

  List<Menu> get _visible {
    final query = _query.trim().toLowerCase();
    return _menuService
        .filtrerParCategorie(_menus, _category)
        .where((m) =>
            query.isEmpty ||
            m.nom.toLowerCase().contains(query) ||
            (m.description?.toLowerCase().contains(query) ?? false))
        .where((m) => !_onlyAlerts || _isAlert(m))
        .toList();
  }

  Future<void> _openForm([Menu? menu]) async {
    if (_archived && menu == null) {
      _snack('Réactivez le restaurant pour ajouter des plats.', error: true);
      return;
    }
    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => MenuFormScreen(
          restaurantId: widget.restaurantId,
          menu: menu,
          restaurantArchived: _archived,
        ),
      ),
    );
  }

  Future<void> _toggle(Menu menu, bool value) async {
    if (value && _archived) {
      _snack('Restaurant archivé : réactivez-le d’abord.', error: true);
      return;
    }
    if (value && menu.quantite == 0) {
      _snack('Stock à 0 : ajoutez des portions avant de remettre en vente.',
          error: true);
      return;
    }
    try {
      await _menuService.modifierDisponibilite(menu.id!, value);
      _snack(
        value ? '${menu.nom} est en vente' : '${menu.nom} retiré de la vente',
      );
    } on MenuValidationException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _delete(Menu menu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce plat ?'),
        content:
            Text('« ${menu.nom} » sera retiré définitivement de la carte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _menuService.supprimerMenu(menu.id!);
      _snack('Plat supprimé');
    } on MenuValidationException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _adjustStock(Menu menu) async {
    final result = await showModalBottomSheet<(int, bool)>(
      context: context,
      showDragHandle: true,
      builder: (_) => _StockSheet(menu: menu, canReEnable: !_archived),
    );
    if (result == null || result.$1 == 0) return;
    await _applyStock(menu, result.$1, reEnable: result.$2);
  }

  /// +1 / -1 directement depuis la liste. Ajouter du stock à un plat épuisé
  /// le remet automatiquement en vente.
  Future<void> _step(Menu menu, int delta) => _applyStock(
        menu,
        delta,
        reEnable: delta > 0 && menu.quantite == 0 && !_archived,
      );

  Future<void> _applyStock(Menu menu, int delta,
      {required bool reEnable}) async {
    try {
      await _menuService.ajusterStock(
        menu.id!,
        delta,
        remettreEnVente: reEnable,
      );
      final stock = menu.quantite + delta;
      if (stock == 0) {
        _snack('${menu.nom} épuisé : passé en « non disponible »');
      } else if (reEnable && !menu.disponible) {
        _snack('${menu.nom} remis en vente ($stock portions)');
      }
    } on MenuValidationException catch (e) {
      _snack(e.message, error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final alerts = _menus.where(_isAlert).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes plats'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un plat'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_archived)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.archivedBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Restaurant archivé : aucun plat n’est visible par '
                        'les clients.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un plat',
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
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: Text('Alertes ($alerts)'),
                          avatar:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          selected: _onlyAlerts,
                          onSelected: (v) => setState(() => _onlyAlerts = v),
                        ),
                        const SizedBox(width: 8),
                        for (final category in [
                          'Toutes',
                          ...MenuService.categories,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${visible.length} plat(s) · +/− pour le stock, touchez un plat pour le modifier',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  if (_menus.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Carte vide. Ajoutez votre premier plat.'),
                      ),
                    )
                  else if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('Aucun plat ne correspond.')),
                    )
                  else
                    for (final menu in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DishTile(
                          menu: menu,
                          onTap: () => _openForm(menu),
                          onMinus: () => _step(menu, -1),
                          onPlus: () => _step(menu, 1),
                          onStockTap: () => _adjustStock(menu),
                          onToggle: (v) => _toggle(menu, v),
                          onDelete: () => _delete(menu),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// Réglage rapide du stock : renvoie la variation (+/-) choisie.
class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.menu, required this.canReEnable});

  final Menu menu;

  /// Proposer de remettre en vente un plat indisponible.
  final bool canReEnable;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  int _delta = 0;
  bool _reEnable = true;

  int get _newStock => widget.menu.quantite + _delta;

  void _add(int value) {
    setState(() => _delta = (_delta + value).clamp(-widget.menu.quantite, 999));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.menu.nom,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock actuel : ${widget.menu.quantite}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _newStock > 0 ? () => _add(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 110,
                  child: Column(
                    children: [
                      Text(
                        '$_newStock',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        _delta == 0
                            ? 'portions'
                            : '${_delta > 0 ? '+' : ''}$_delta',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _add(1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final step in [5, 10, 20])
                  ActionChip(
                    label: Text('+$step'),
                    onPressed: () => _add(step),
                  ),
                ActionChip(
                  label: const Text('Mettre à 0'),
                  onPressed: () =>
                      setState(() => _delta = -widget.menu.quantite),
                ),
              ],
            ),
            if (!widget.menu.disponible && widget.canReEnable)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reEnable && _newStock > 0,
                onChanged:
                    _newStock > 0 ? (v) => setState(() => _reEnable = v) : null,
                title: const Text('Remettre en vente'),
                subtitle: Text(
                  _newStock > 0
                      ? 'Le plat redevient réservable par les clients.'
                      : 'Impossible sans stock.',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _delta == 0
                  ? null
                  : () => Navigator.of(context)
                      .pop((_delta, _reEnable && _newStock > 0)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Valider le stock'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne compacte d'un plat : stock réglable sur place, mise en vente,
/// menu (modifier / supprimer).
class _DishTile extends StatelessWidget {
  const _DishTile({
    required this.menu,
    required this.onTap,
    required this.onMinus,
    required this.onPlus,
    required this.onStockTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Menu menu;
  final VoidCallback onTap;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onStockTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = menu.quantite == 0;
    final low = !soldOut && menu.quantite <= MenuService.seuilStockBas;
    final (label, color) = !menu.disponible
        ? (soldOut ? 'Épuisé' : 'Hors vente', AppColors.error)
        : low
            ? ('Stock bas', AppColors.warning)
            : ('En vente', AppColors.primary);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.nom,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${menu.categorie} · ${menu.prix.toStringAsFixed(menu.prix % 1 == 0 ? 0 : 2)} DT',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Plus',
                    onSelected: (v) => v == 'edit' ? onTap() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: soldOut ? null : onMinus,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  InkWell(
                    onTap: onStockTap,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Text(
                            '${menu.quantite}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: soldOut ? AppColors.error : null,
                            ),
                          ),
                          Text(
                            'en stock',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: onPlus,
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                  const Spacer(),
                  Text(
                    menu.disponible ? 'En vente' : 'Hors vente',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  Switch(value: menu.disponible, onChanged: onToggle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
