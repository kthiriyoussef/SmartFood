import 'package:bcrypt/bcrypt.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class AuthService {
  static final instance = AuthService._();
  AuthService._() : _testDb = null;
  AuthService.forTesting(Database db) : _testDb = db;
  final Database? _testDb;
  Future<Database> get _db async => _testDb ?? await DatabaseHelper.instance.database;

  static String? validatePassword(String value) =>
      value.length < 10 ? 'Mot de passe : 10 caractères minimum.' : null;

  // Never expose the password hash to UI or session storage.
  Map<String, Object?> _publicUser(Map<String, Object?> row) {
    final copy = Map<String, Object?>.from(row);
    copy.remove('password_hash');
    return copy;
  }

  Future<Map<String, Object?>> register({
    required String nom, required String prenom,
    required String email, required String password,
  }) async {
    final db = await _db;
    final normalized = email.trim().toLowerCase();
    if (nom.trim().isEmpty || prenom.trim().isEmpty) {
      throw Exception('Nom et prénom obligatoires.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw Exception('Adresse email invalide.');
    }
    final problem = validatePassword(password);
    if (problem != null) throw Exception(problem);
    final exists = await db.query('users', where: 'email = ?', whereArgs: [normalized], limit: 1);
    if (exists.isNotEmpty) throw Exception('Cet email est déjà utilisé.');
    final id = await db.insert('users', {
      'nom': nom.trim(), 'prenom': prenom.trim(), 'email': normalized,
      'password_hash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'role': 'CLIENT', 'actif': 1,
    });
    return getUserById(id).then((user) => user!);
  }

  Future<Map<String, Object?>> login(String email, String password) async {
    final db = await _db;
    final rows = await db.query('users', where: 'email = ?',
        whereArgs: [email.trim().toLowerCase()], limit: 1);
    if (rows.isEmpty) throw Exception('Email ou mot de passe incorrect.');
    final user = rows.single;
    if (user['actif'] != 1) throw Exception('Compte désactivé.');
    if (!BCrypt.checkpw(password, user['password_hash'] as String)) {
      throw Exception('Email ou mot de passe incorrect.');
    }
    return _publicUser(user);
  }

  Future<Map<String, Object?>?> getUserById(int id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ? AND actif = 1',
        whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _publicUser(rows.single);
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ? AND actif = 1',
        whereArgs: [userId], limit: 1);
    if (rows.isEmpty) throw Exception('Compte introuvable ou désactivé.');
    final previousHash = rows.single['password_hash'] as String;
    if (!BCrypt.checkpw(currentPassword, previousHash)) {
      throw Exception('Mot de passe actuel incorrect.');
    }
    final problem = validatePassword(newPassword);
    if (problem != null) throw Exception(problem);
    if (BCrypt.checkpw(newPassword, previousHash)) {
      throw Exception('Choisissez un mot de passe différent.');
    }
    await db.update('users', {
      'password_hash': BCrypt.hashpw(newPassword, BCrypt.gensalt()),
    }, where: 'id = ? AND password_hash = ?', whereArgs: [userId, previousHash]);
  }
}
