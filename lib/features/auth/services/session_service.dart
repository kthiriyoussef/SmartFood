import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';

/// Persists only the local account ID, never the password or its hash.
/// The account is re-validated in SQLite on every app startup.
class SessionService {
  static final instance = SessionService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _key = 'smartfood_logged_in_user_id';

  Future<void> saveUser(int userId) async =>
      _storage.write(key: _key, value: userId.toString());

  Future<Map<String, Object?>?> restoreUser() async {
    final raw = await _storage.read(key: _key);
    final id = int.tryParse(raw ?? '');
    if (id == null) {
      await clear();
      return null;
    }
    final user = await AuthService.instance.getUserById(id);
    if (user == null) await clear();
    return user;
  }

  Future<void> clear() async => _storage.delete(key: _key);
}
