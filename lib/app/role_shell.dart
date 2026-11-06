import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';

/// Un onglet de la barre du bas.
class ShellTab {
  const ShellTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.root,
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget root;

  /// Nombre affiché en pastille (ex. réservations à traiter). Null = aucun.
  final ValueListenable<int>? badgeCount;
}

/// Barre de navigation unique, toujours visible, commune aux deux rôles.
///
/// - chaque onglet a son propre Navigator (la barre reste affichée quand on
///   ouvre un écran, et chaque onglet garde sa pile) ;
/// - re-toucher l'onglet courant ramène à sa racine ;
/// - le dernier bouton sert à changer de rôle (client ↔ restaurant).
class RoleShell extends StatefulWidget {
  const RoleShell({
    super.key,
    required this.tabs,
    required this.switchLabel,
    required this.switchIcon,
    required this.onSwitchRole,
  });

  final List<ShellTab> tabs;
  final String switchLabel;
  final IconData switchIcon;
  final VoidCallback onSwitchRole;

  static RoleShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<RoleShellState>();

  @override
  State<RoleShell> createState() => RoleShellState();
}

class RoleShellState extends State<RoleShell> {
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    for (var i = 0; i < widget.tabs.length; i++) GlobalKey<NavigatorState>(),
  ];

  int _index = 0;

  /// Ouvre un onglet depuis n'importe quel écran (ex. confirmation →
  /// « Mes réservations »).
  void selectTab(int index) => _select(index, resetStack: true);

  void _select(int index, {bool resetStack = false}) {
    if (index == widget.tabs.length) {
      widget.onSwitchRole();
      return;
    }
    if (index == _index || resetStack) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    if (index != _index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = _navigatorKeys[_index].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              Navigator(
                key: _navigatorKeys[i],
                onGenerateRoute: (settings) => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => widget.tabs[i].root,
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.successBackground,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black26,
          elevation: 8,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final tab in widget.tabs)
              NavigationDestination(
                icon: _BadgeIcon(icon: tab.icon, count: tab.badgeCount),
                selectedIcon: _BadgeIcon(
                  icon: tab.selectedIcon,
                  count: tab.badgeCount,
                  color: AppColors.primary,
                ),
                label: tab.label,
              ),
            NavigationDestination(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.switchIcon, color: AppColors.secondary),
              ),
              label: widget.switchLabel,
              tooltip: 'Se déconnecter',
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, this.count, this.color});

  final IconData icon;
  final ValueListenable<int>? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color);
    final listenable = count;
    if (listenable == null) return iconWidget;
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (context, value, child) => Badge(
        isLabelVisible: value > 0,
        backgroundColor: AppColors.secondary,
        label: Text('$value'),
        child: child,
      ),
      child: iconWidget,
    );
  }
}
