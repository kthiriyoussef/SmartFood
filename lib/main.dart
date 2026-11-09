import 'package:flutter/material.dart';
import 'package:smartfood/app/role_scope.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/auth/screens/login_screen.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';
import 'package:smartfood/features/admin/screens/admin_shell.dart';
import 'package:smartfood/features/auth/services/session_service.dart';
import 'package:smartfood/features/restaurants/screens/restaurant_form_screen.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFoodApp());
}

class SmartFoodApp extends StatelessWidget {
  const SmartFoodApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SmartFood',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Map<String, Object?>? _user;
  bool _loading = true;
  bool _needsRestaurantSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    debugPrint('ETAPE 1 : Début restauration session');

    Map<String, Object?>? user;
    var needsRestaurantSetup = false;

    try {
      debugPrint('ETAPE 2 : Appel SessionService');

      user = await SessionService.instance.restoreUser();
      if (user != null) {
        needsRestaurantSetup = await _needsRestaurantSetupFor(user);
      }

      debugPrint('ETAPE 3 : Session restaurée : $user');
    } catch (e, stackTrace) {
      debugPrint('ERREUR RESTAURATION : $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger votre session. Réessayez.';
        _loading = false;
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _user = user;
      _needsRestaurantSetup = needsRestaurantSetup;
      _error = null;
      _loading = false;
    });

    debugPrint('ETAPE 4 : Fin restauration');
  }

  Future<void> _authenticated(Map<String, Object?> user) async {
    final id = user['id'] as int?;
    if (id == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await SessionService.instance.saveUser(id);
      final latestUser = await AuthService.instance.getUserById(id);
      if (latestUser == null) {
        throw StateError('Compte introuvable ou désactivé.');
      }
      final needsRestaurantSetup = await _needsRestaurantSetupFor(latestUser);
      if (!mounted) return;
      setState(() {
        _user = latestUser;
        _needsRestaurantSetup = needsRestaurantSetup;
        _loading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Impossible de terminer la connexion : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de préparer votre compte. Réessayez.';
      });
    }
  }

  Future<bool> _needsRestaurantSetupFor(
    Map<String, Object?> user,
  ) async {
    final id = user['id'] as int?;
    if (id == null) {
      throw StateError('Identifiant utilisateur manquant.');
    }
    final destination = await RestaurantService().getPostLoginDestination(
      userId: id,
      role: user['role'] as String? ?? 'CLIENT',
    );
    return destination == RestaurantPostLoginDestination.createRestaurant;
  }

  void _restaurantCreated(int restaurantId) {
    final user = _user;
    if (user == null) return;
    setState(() {
      _user = {...user, 'restaurant_id': restaurantId};
      _needsRestaurantSetup = false;
    });
  }

  Future<void> _logout() async {
    try {
      await SessionService.instance.clear();
    } catch (e) {
      debugPrint('Impossible de supprimer la session : $e');
      return;
    }
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(
                onPressed: _restore,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final user = _user;
    if (user == null) {
      return LoginScreen(onAuthenticated: _authenticated);
    }
    final role = user['role'] as String? ?? 'CLIENT';
    if (role == 'ADMIN') {
      return AdminShell(
        key: ValueKey('admin-${user['id']}'),
        userId: user['id'] as int,
        onLogout: _logout,
      );
    }
    if (_needsRestaurantSetup) {
      return RestaurantFormScreen(
        key: ValueKey('restaurant-onboarding-${user['id']}'),
        ownerUserId: user['id'] as int,
        onOwnerRestaurantCreated: _restaurantCreated,
      );
    }
    return RoleScope(
      key: ValueKey(user['id']),
      userId: user['id'] as int,
      initialRole: ['RESTO', 'RESTAURANT'].contains(role.toUpperCase())
          ? AppRole.restaurant
          : AppRole.client,
      onLogout: _logout,
    );
  }
}
