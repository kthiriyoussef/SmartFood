import 'package:flutter/material.dart';

import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/features/admin/screens/admin_dashboard_screen.dart';
import 'package:smartfood/features/admin/screens/admin_resto_requests_screen.dart';
import 'package:smartfood/features/admin/screens/admin_restaurant_access_screen.dart';
import 'package:smartfood/features/users/screens/admin_users_screen.dart';
import 'package:smartfood/features/auth/screens/change_password_screen.dart';
import 'package:smartfood/features/reclamation/screens/admin_reclamations_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  final int userId;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      switchLabel: 'Déconnexion',
      switchIcon: Icons.logout_rounded,
      onSwitchRole: onLogout,
      tabs: [
        ShellTab(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Accueil',
          root: AdminDashboardScreen(
            actorId: userId,
          ),
        ),
        ShellTab(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Comptes',
          root: AdminUsersScreen(
            actorId: userId,
          ),
        ),
        ShellTab(
          icon: Icons.pending_actions_outlined,
          selectedIcon: Icons.pending_actions,
          label: 'Demandes RESTO',
          root: AdminRestoRequestsScreen(
            actorId: userId,
          ),
        ),
        ShellTab(
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          label: 'Demandes d’accès',
          root: AdminRestaurantAccessScreen(
            actorId: userId,
          ),
        ),
        ShellTab(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Réclamations',
          root: AdminReclamationsScreen(
            adminId: userId,
          ),
        ),
        ShellTab(
          icon: Icons.lock_outline,
          selectedIcon: Icons.lock,
          label: 'Sécurité',
          root: ChangePasswordScreen(
            userId: userId,
          ),
        ),
      ],
    );
  }
}
