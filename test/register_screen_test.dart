import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfood/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('registration includes desired account type, not a restaurant',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Adresse email'), findsOneWidget);
    expect(find.text('Mot de passe (10 caractères minimum)'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('What type of account would you like?'), findsOneWidget);
    expect(find.text('Customer / Normal User'), findsOneWidget);
    expect(find.text('Restaurant Owner'), findsOneWidget);
    expect(find.text('Votre restaurant'), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
  });
}
