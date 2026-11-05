import 'package:flutter/material.dart';
import 'package:smartfood/app/role_scope.dart';
import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/screens/reservation_history_client_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/screens/client_restaurant_catalog_screen.dart';
import 'package:smartfood/features/users/screens/client_profile_screen.dart';

/// Espace client : Accueil · Réservations · Profil · [Espace resto].
class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  static const int homeTab = 0;
  static const int reservationsTab = 1;
  static const int profileTab = 2;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  /// Réservations en cours du client (pastille sur l'onglet).
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
    final reservations = await ReservationService().getReservations();
    if (!mounted) return;
    _activeCount.value = reservations.where((r) => r.isActive).length;
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      switchLabel: 'Espace resto',
      switchIcon: Icons.storefront_rounded,
      onSwitchRole: () => RoleScope.of(context).switchTo(AppRole.restaurant),
      tabs: [
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
      ],
    );
  }
}
