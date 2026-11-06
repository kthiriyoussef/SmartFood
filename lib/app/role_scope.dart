import 'package:flutter/material.dart';
import 'package:smartfood/app/client_shell.dart';
import 'package:smartfood/app/restaurant_shell.dart';

enum AppRole { client, restaurant }

class RoleScope extends StatefulWidget {
  const RoleScope({super.key, required this.initialRole, required this.userId, required this.onLogout});
  final AppRole initialRole;
  final int userId;
  final VoidCallback onLogout;

  static RoleScopeState of(BuildContext context) =>
      context.findAncestorStateOfType<RoleScopeState>()!;

  @override
  State<RoleScope> createState() => RoleScopeState();
}

class RoleScopeState extends State<RoleScope> {
  AppRole get role => widget.initialRole;
  int get userId => widget.userId;
  void logout() => widget.onLogout();
  @override
  Widget build(BuildContext context) => widget.initialRole == AppRole.client
      ? const ClientShell()
      : const RestaurantShell();
}
