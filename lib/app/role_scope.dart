import 'package:flutter/material.dart';
import 'package:smartfood/app/client_shell.dart';
import 'package:smartfood/app/restaurant_shell.dart';

/// Rôle courant de l'application. Pas encore d'authentification : on bascule
/// librement entre les deux espaces pour les tests (bouton dans la barre).
enum AppRole { client, restaurant }

/// Racine de l'application : affiche l'espace correspondant au rôle courant.
class RoleScope extends StatefulWidget {
  const RoleScope({super.key, this.initialRole = AppRole.client});

  final AppRole initialRole;

  static RoleScopeState of(BuildContext context) =>
      context.findAncestorStateOfType<RoleScopeState>()!;

  @override
  State<RoleScope> createState() => RoleScopeState();
}

class RoleScopeState extends State<RoleScope> {
  late AppRole _role = widget.initialRole;

  AppRole get role => _role;

  void switchTo(AppRole role) {
    if (role == _role) return;
    setState(() => _role = role);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            role == AppRole.client ? 'Espace client' : 'Espace restaurant',
          ),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _role == AppRole.client
          ? const ClientShell(key: ValueKey(AppRole.client))
          : const RestaurantShell(key: ValueKey(AppRole.restaurant)),
    );
  }
}
