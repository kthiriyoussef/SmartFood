import 'package:smartfood/features/auth/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:smartfood/app/role_scope.dart';
import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/restaurant/reservation_list_restaurant.dart';
import 'package:smartfood/features/reservations/screens/restaurant/restaurant_monitor_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/menu_list_screen.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/restaurant_dashboard_screen.dart';

/// Espace restaurant (un seul restaurant : le « Restaurant Test »).
/// Tableau de bord · Suivi · Plats · Historique · [Espace client].
/// L'ordre des onglets correspond à [RestaurantTabs].
class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key});

  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell> {
  final _pendingCount = ValueNotifier<int>(0);
  int? _restaurantId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
    DataChanges.reservations.addListener(_refreshBadge);
  }

  @override
  void dispose() {
    DataChanges.reservations.removeListener(_refreshBadge);
    _pendingCount.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final userId = RoleScope.of(context).userId;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('users',
      columns: ['restaurant_id'], where: "id = ? AND role = 'RESTO' AND actif = 1",
      whereArgs: [userId], limit: 1);
    final id = rows.isEmpty ? null : rows.first['restaurant_id'] as int?;
    if (!mounted) return;
    setState(() { _restaurantId = id; _loaded = true; });
    _refreshBadge();
  }

  /// Pastille : réservations « En attente » de ce restaurant.
  Future<void> _refreshBadge() async {
    final id = _restaurantId;
    if (id == null) return;
    final reservations =
    await ReservationService().getReservations(restaurantId: id);
    if (!mounted) return;
    _pendingCount.value = reservations
        .where((r) => r.status == ReservationStatus.enAttente)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final id = _restaurantId;
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (id == null) {
      return Scaffold(appBar: AppBar(title: const Text('SmartFood RESTO')),
        body: const Center(child: Text(
          'Aucun restaurant associé à ce compte. Contactez un administrateur.')));
    }
    return RoleShell(
      switchLabel: 'Déconnexion',
      switchIcon: Icons.logout_rounded,
      onSwitchRole: () => RoleScope.of(context).logout(),
      tabs: [
        ShellTab(
          icon: Icons.lock_outline,
          selectedIcon: Icons.lock_rounded,
          label: 'Sécurité',
          root: ChangePasswordScreen(userId: RoleScope.of(context).userId),
        ),
        ShellTab(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Accueil',
          root: RestaurantDashboardScreen(restaurantId: id),
          badgeCount: _pendingCount,
        ),
        ShellTab(
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart_rounded,
          label: 'Suivi',
          root: RestaurantMonitorScreen(restaurantId: id),
        ),
        ShellTab(
          icon: Icons.restaurant_menu_outlined,
          selectedIcon: Icons.restaurant_menu_rounded,
          label: 'Plats',
          root: MenuListScreen(restaurantId: id),
        ),
        ShellTab(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          label: 'Historique',
          root: ReservationListScreen(restaurantId: id),
        ),
      ],
    );
  }
}
