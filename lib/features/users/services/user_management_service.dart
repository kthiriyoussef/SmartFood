
import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';

class UserManagementService {
  UserManagementService({Database? testDatabase})
      : _testDatabase = testDatabase;
  final Database? _testDatabase;
  Future<Database> get _db async =>
      _testDatabase ?? await DatabaseHelper.instance.database;

  Future<void> _requireAdmin(Database db, int actorId) async {
    final rows = await db.query('users',
        columns: ['role', 'actif'],
        where: 'id = ?', whereArgs: [actorId], limit: 1);
    if (rows.isEmpty || rows.first['role'] != 'ADMIN' ||
        rows.first['actif'] != 1) {
      throw StateError('Accès réservé à un administrateur actif.');
    }
  }

  Future<List<Map<String, Object?>>> listUsers({
    required int actorId, String search = '',
  }) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    final q = search.trim();
    return db.query('users',
      columns: ['id', 'nom', 'prenom', 'email', 'role',
        'restaurant_id', 'actif'],
      where: q.isEmpty ? null :
          '(nom LIKE ? OR prenom LIKE ? OR email LIKE ?)',
      whereArgs: q.isEmpty ? null : List.filled(3, '%$q%'),
      orderBy: 'id DESC');
  }

  Future<List<Map<String, Object?>>> restaurants({
    required int actorId,
  }) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    return db.query('restaurants', columns: ['id', 'nom'],
        where: "statut = 'actif'", orderBy: 'nom');
  }

  Future<Map<String, int>> statistics({required int actorId}) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    return {
      'total': await count('SELECT COUNT(*) FROM users'),
      'active': await count('SELECT COUNT(*) FROM users WHERE actif = 1'),
      'inactive': await count('SELECT COUNT(*) FROM users WHERE actif = 0'),
      'resto': await count("SELECT COUNT(*) FROM users WHERE role = 'RESTO'"),
      'client': await count("SELECT COUNT(*) FROM users WHERE role = 'CLIENT'"),
      'restaurants': await count('SELECT COUNT(*) FROM restaurants'),
    };
  }

  Future<int> createUser({
    required int actorId, required String nom, required String prenom,
    required String email, required String password,
    required String role, int? restaurantId,
  }) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    final normalized = email.trim().toLowerCase();
    _validate(nom, prenom, normalized, role, restaurantId);
    if (AuthService.validatePassword(password) != null) {
      throw ArgumentError('Mot de passe : 10 caractères minimum.');
    }
    await _validateRestaurant(db, role, restaurantId);
    return db.insert('users', {
      'nom': nom.trim(), 'prenom': prenom.trim(), 'email': normalized,
      'password_hash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'role': role, 'restaurant_id': role == 'RESTO' ? restaurantId : null,
      'actif': 1,
    });
  }

  Future<void> updateUser({
    required int actorId, required int userId,
    required String nom, required String prenom, required String email,
    required String role, int? restaurantId,
  }) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    if (actorId == userId && role != 'ADMIN') {
      throw StateError('Vous ne pouvez pas retirer votre propre rôle ADMIN.');
    }
    final normalized = email.trim().toLowerCase();
    _validate(nom, prenom, normalized, role, restaurantId);
    await _validateRestaurant(db, role, restaurantId);
    final updated = await db.update('users', {
      'nom': nom.trim(), 'prenom': prenom.trim(), 'email': normalized,
      'role': role, 'restaurant_id': role == 'RESTO' ? restaurantId : null,
    }, where: 'id = ?', whereArgs: [userId]);
    if (updated == 0) throw StateError('Utilisateur introuvable.');
  }

  Future<void> setActive({
    required int actorId, required int userId, required bool active,
  }) async {
    final db = await _db;
    await _requireAdmin(db, actorId);
    if (actorId == userId && !active) {
      throw StateError('Impossible de désactiver votre propre compte.');
    }
    final changed = await db.update('users', {'actif': active ? 1 : 0},
        where: 'id = ?', whereArgs: [userId]);
    if (changed == 0) throw StateError('Utilisateur introuvable.');
  }

  // Soft delete: preserves reservation/history references.
  Future<void> deleteUser({
    required int actorId, required int userId,
  }) => setActive(actorId: actorId, userId: userId, active: false);

  void _validate(String nom, String prenom, String email, String role,
      int? restaurantId) {
    if (nom.trim().isEmpty || prenom.trim().isEmpty) {
      throw ArgumentError('Nom et prénom obligatoires.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Email invalide.');
    }
    if (!['ADMIN', 'RESTO', 'CLIENT'].contains(role)) {
      throw ArgumentError('Rôle invalide.');
    }
    if (role == 'RESTO' && restaurantId == null) {
      throw ArgumentError('Sélectionnez un restaurant pour RESTO.');
    }
  }

  Future<void> _validateRestaurant(
      Database db, String role, int? restaurantId) async {
    if (role != 'RESTO') return;
    final rows = await db.query('restaurants', columns: ['id'],
        where: "id = ? AND statut = 'actif'",
        whereArgs: [restaurantId], limit: 1);
    if (rows.isEmpty) throw ArgumentError('Restaurant introuvable ou archivé.');
  }
}
