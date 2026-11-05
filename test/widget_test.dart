import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfood/app/role_shell.dart';

void main() {
  testWidgets('La barre affiche les onglets et le bouton de changement de rôle',
      (WidgetTester tester) async {
    var switched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RoleShell(
          switchLabel: 'Espace resto',
          switchIcon: Icons.storefront_rounded,
          onSwitchRole: () => switched = true,
          tabs: const [
            ShellTab(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Accueil',
              root: Text('page accueil'),
            ),
            ShellTab(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profil',
              root: Text('page profil'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('page accueil'), findsOneWidget);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('page profil'), findsOneWidget);

    await tester.tap(find.text('Espace resto'));
    expect(switched, isTrue);
  });
}
