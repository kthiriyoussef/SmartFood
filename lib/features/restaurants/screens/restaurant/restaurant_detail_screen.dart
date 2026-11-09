import 'package:flutter/material.dart';
import 'package:smartfood/app/restaurant_tabs.dart';
import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/restaurant_form_screen.dart';
import 'package:smartfood/features/restaurants/services/menu_service.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';
import 'package:smartfood/features/restaurants/widgets/restaurant_status_badge.dart';

/// Fiche de gestion d'un restaurant : chiffres clés, alertes, accès à la
/// carte et aux réservations, archivage.
class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _restaurantService = RestaurantService();
  final _menuService = MenuService();
  final _reservationService = ReservationService();

  Restaurant? _restaurant;
  List<Menu> _menus = const [];
  List<Reservation> _reservations = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    DataChanges.catalog.addListener(_load);
    DataChanges.reservations.addListener(_load);
  }

  @override
  void dispose() {
    DataChanges.catalog.removeListener(_load);
    DataChanges.reservations.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final restaurant =
        await _restaurantService.getRestaurantById(widget.restaurantId);
    final menus = await _menuService.getMenusByRestaurant(widget.restaurantId);
    final reservations = await _reservationService.getReservations(
      restaurantId: widget.restaurantId,
    );
    if (!mounted) return;
    setState(() {
      _restaurant = restaurant;
      _menus = menus;
      _reservations = reservations;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RestaurantFormScreen(restaurant: _restaurant),
      ),
    );
  }

  Future<void> _toggleArchive() async {
    final restaurant = _restaurant!;
    final archiving = restaurant.statut == RestaurantStatus.actif;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            archiving ? 'Fermer le restaurant ?' : 'Rouvrir le restaurant ?'),
        content: Text(
          archiving
              ? 'Il disparaîtra de l’application client et tous ses plats '
                  'deviendront indisponibles.'
              : 'Le restaurant sera de nouveau visible. Vos plats restent '
                  'indisponibles : remettez-les en vente depuis la carte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: archiving
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(archiving ? 'Fermer' : 'Rouvrir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      if (archiving) {
        await _restaurantService.archiverRestaurant(restaurant.id!);
      } else {
        await _restaurantService.reactiverRestaurant(restaurant.id!);
      }
      _snack(archiving ? 'Restaurant fermé' : 'Restaurant rouvert');
    } on RestaurantValidationException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Les plats et le suivi sont des onglets de l'espace restaurant.
  void _openMenus() => RoleShell.of(context)?.selectTab(RestaurantTabs.dishes);

  void _openReservations({String? status}) =>
      RoleShell.of(context)?.selectTab(RestaurantTabs.monitor);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final restaurant = _restaurant;
    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ce restaurant n’existe plus.')),
      );
    }

    final isActive = restaurant.statut == RestaurantStatus.actif;
    final available = _menus.where((m) => m.disponible && m.quantite > 0);
    final outOfStock = _menus.where((m) => m.disponible && m.quantite == 0);
    final lowStock = _menus.where(
      (m) =>
          m.disponible &&
          m.quantite > 0 &&
          m.quantite <= MenuService.seuilStockBas,
    );
    final active = _reservations.where((r) => r.isActive).toList()
      ..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
    final pending =
        active.where((r) => r.status == ReservationStatus.enAttente).length;
    final revenue = _reservations
        .where((r) => r.status == ReservationStatus.recuperee)
        .fold<double>(0, (sum, r) => sum + r.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon restaurant'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Header(restaurant: restaurant),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  value: '${available.length}/${_menus.length}',
                  label: 'Plats en vente',
                  icon: Icons.restaurant_menu_rounded,
                ),
                const SizedBox(width: 10),
                _Stat(
                  value: '${active.length}',
                  label: 'Réservations en cours',
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(width: 10),
                _Stat(
                  value: revenue.toStringAsFixed(revenue % 1 == 0 ? 0 : 1),
                  label: 'DT encaissés',
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!isActive)
              const _Alert(
                icon: Icons.archive_outlined,
                color: AppColors.error,
                text: 'Restaurant fermé : invisible pour les clients.',
              ),
            if (pending > 0)
              _Alert(
                icon: Icons.notifications_active_outlined,
                color: AppColors.secondary,
                text: '$pending réservation(s) à confirmer',
                onTap: () =>
                    _openReservations(status: ReservationStatus.enAttente),
              ),
            if (outOfStock.isNotEmpty)
              _Alert(
                icon: Icons.inventory_2_outlined,
                color: AppColors.error,
                text: 'En rupture : ${outOfStock.map((m) => m.nom).join(', ')}',
                onTap: _openMenus,
              ),
            if (lowStock.isNotEmpty)
              _Alert(
                icon: Icons.trending_down_rounded,
                color: AppColors.warning,
                text:
                    'Stock bas : ${lowStock.map((m) => '${m.nom} (${m.quantite})').join(', ')}',
                onTap: _openMenus,
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _toggleArchive,
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? AppColors.error : AppColors.primary,
                side: BorderSide(
                  color: isActive ? AppColors.error : AppColors.primary,
                ),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: Icon(
                isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
              ),
              label: Text(
                isActive ? 'Fermer le restaurant' : 'Rouvrir le restaurant',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = Colors.white.withAlpha(220);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C4E25), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant.nom,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              RestaurantStatusBadge(status: restaurant.statut),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: textColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${restaurant.adresse}, ${restaurant.ville}',
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 18, color: textColor),
              const SizedBox(width: 6),
              Text(restaurant.telephone, style: TextStyle(color: textColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
