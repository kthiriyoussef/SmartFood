// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfood/features/reservations/screens/reservation_history_client_screen.dart';
import 'package:smartfood/main.dart';

void main() {
  testWidgets('SmartFood reservation navigation screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartFoodApp());

    expect(find.text('Navigation provisoire'), findsOneWidget);
    expect(find.text('Créer réservation'), findsOneWidget);
  });

  testWidgets('Client reservation history shows restaurant and reservation reference', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReservationHistoryClientScreen()));

    expect(find.text('Sonia Ben Ali'), findsWidgets);
    expect(find.textContaining('res -'), findsWidgets);
    expect(find.textContaining('Le Petit Jardin'), findsWidgets);
  });
}
