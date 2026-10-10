import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/screens/reservation_navigation_screen.dart';

void main() {
  runApp(const SmartFoodApp());
}

class SmartFoodApp extends StatelessWidget {
  const SmartFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
     home: const ReservationNavigationScreen(),
    );
  }
}
