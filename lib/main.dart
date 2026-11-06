import 'package:flutter/material.dart';
import 'package:smartfood/app/role_scope.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/auth/screens/login_screen.dart';
import 'package:smartfood/features/admin/screens/admin_shell.dart';
import 'package:smartfood/features/auth/services/session_service.dart';

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

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    debugPrint('ETAPE 1 : Début restauration session');

    Map<String, Object?>? user;

    try {
      debugPrint('ETAPE 2 : Appel SessionService');

      user = await SessionService.instance.restoreUser();

      debugPrint('ETAPE 3 : Session restaurée : $user');
    } catch (e, stackTrace) {
      debugPrint('ERREUR RESTAURATION : $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;

    setState(() {
      _user = user;
      _loading = false;
    });

    debugPrint('ETAPE 4 : Fin restauration');
  }

  Future<void> _authenticated(Map<String, Object?> user) async {
    final id = user['id'] as int?;
    if (id == null) return;
    try {
      await SessionService.instance.saveUser(id);
    } catch (e) {
      debugPrint('Impossible de sauvegarder la session : $e');
    }
    if (mounted) setState(() => _user = user);
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
    return RoleScope(
      key: ValueKey(user['id']),
      userId: user['id'] as int,
      initialRole: role == 'RESTO' ? AppRole.restaurant : AppRole.client,
      onLogout: _logout,
    );
  }
}
