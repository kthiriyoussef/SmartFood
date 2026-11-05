import 'package:flutter/material.dart';
import 'package:smartfood/app/role_scope.dart';
import 'package:smartfood/app/theme.dart';

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
      // Pas encore d'authentification : on démarre côté client et on bascule
      // vers l'espace restaurant avec le bouton de la barre du bas.
      home: const RoleScope(),
    );
  }
}
