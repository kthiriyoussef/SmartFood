import 'package:smartfood/features/auth/screens/change_password_screen.dart';

import 'package:flutter/material.dart';

import 'role_scope.dart';
import 'role_shell.dart';

import '../core/database/data_changes.dart';
import '../features/reservations/screens/reservation_history_client_screen.dart';
import '../features/reservations/services/reservation_service.dart';
import '../features/restaurants/screens/client_restaurant_catalog_screen.dart';
import '../features/restaurants/screens/restaurant_access_status_screen.dart';
import '../features/users/screens/client_profile_screen.dart';
import '../features/reclamation/screens/support_navigation_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  static const int homeTab = 0;
  static const int reservationsTab = 1;
  static const int profileTab = 2;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final _activeCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _refreshBadge();
    DataChanges.reservations.addListener(_refreshBadge);
  }

  @override
  void dispose() {
    DataChanges.reservations.removeListener(_refreshBadge);
    _activeCount.dispose();
    super.dispose();
  }

  Future<void> _refreshBadge() async {
    final reservations =
    await ReservationService().getReservations();

    if (!mounted) return;

    _activeCount.value =
        reservations.where((r) => r.isActive).length;
  }

  @override
  Widget build(BuildContext context) {
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
        const ShellTab(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Accueil',
          root: ClientRestaurantCatalogScreen(),
        ),
        ShellTab(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: 'Réservations',
          root: const ReservationHistoryClientScreen(),
          badgeCount: _activeCount,
        ),
        const ShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profil',
          root: ClientProfileScreen(),
        ),
        ShellTab(
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          label: 'Accès resto',
          root: RestaurantAccessStatusScreen(
            userId: RoleScope.of(context).userId,
          ),
        ),
        const ShellTab(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent_rounded,
          label: 'Réclamations',
          root: SupportNavigationScreen(),
        ),
      ],
    );
  }
}
