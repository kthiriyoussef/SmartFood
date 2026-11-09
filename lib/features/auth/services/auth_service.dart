import 'package:bcrypt/bcrypt.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class AuthService {
  static final instance = AuthService._();

  AuthService._() : _testDb = null;

  AuthService.forTesting(Database db) : _testDb = db;

  final Database? _testDb;

  Future<Database> get _db async =>
      _testDb ?? await DatabaseHelper.instance.database;

  // ============================================================
  // VALIDATION DU MOT DE PASSE
  // ============================================================

  static String? validatePassword(String value) {
    if (value.length < 10) {
      return 'Mot de passe : 10 caractères minimum.';
    }
    return null;
  }

  // ============================================================
  // PROTECTION DES DONNEES UTILISATEUR
  // ============================================================

  // Ne jamais exposer le hash du mot de passe
  // dans l'interface ou dans la session.
  Map<String, Object?> _publicUser(
    Map<String, Object?> row,
  ) {
    final copy = Map<String, Object?>.from(row);
    copy.remove('password_hash');
    return copy;
  }

  // ============================================================
  // INSCRIPTION
  // ============================================================

  Future<Map<String, Object?>> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    bool requestRestaurantAccess = false,
  }) async {
    final db = await _db;

    final normalized = email.trim().toLowerCase();

    // Validation nom et prenom
    if (nom.trim().isEmpty || prenom.trim().isEmpty) {
      throw Exception('Nom et prénom obligatoires.');
    }

    // Validation email
    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(normalized)) {
      throw Exception('Adresse email invalide.');
    }

    // Validation mot de passe
    final problem = validatePassword(password);

    if (problem != null) {
      throw Exception(problem);
    }

    // Vérifier si l'email existe déjà
    final exists = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalized],
      limit: 1,
    );

    if (exists.isNotEmpty) {
      throw Exception('Cet email est déjà utilisé.');
    }

    // Hash sécurisé du mot de passe
    final passwordHash = BCrypt.hashpw(
      password,
      BCrypt.gensalt(),
    );

    final userId = await db.transaction<int>((txn) async {
      final id = await txn.insert('users', {
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'email': normalized,
        'password_hash': passwordHash,
        'role': 'CLIENT',
        'actif': 1,
      });
      if (requestRestaurantAccess) {
        await _insertRestaurantAccessRequest(
          txn,
          id,
          '${prenom.trim()} ${nom.trim()}',
          normalized,
        );
      }
      return id;
    });

    // Récupérer l'utilisateur créé
    final user = await getUserById(userId);

    if (user == null) {
      throw StateError(
        'Compte créé mais introuvable.',
      );
    }

    return user;
  }

  // ============================================================
  // CONNEXION
  // ============================================================

  Future<Map<String, Object?>> login(
    String email,
    String password,
  ) async {
    final db = await _db;

    final normalized = email.trim().toLowerCase();

    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [normalized],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception(
        'Email ou mot de passe incorrect.',
      );
    }

    final user = rows.single;

    // Vérifier si le compte est actif
    if (user['actif'] != 1) {
      throw Exception('Compte désactivé.');
    }

    // Vérifier le mot de passe BCrypt
    final validPassword = BCrypt.checkpw(
      password,
      user['password_hash'] as String,
    );

    if (!validPassword) {
      throw Exception(
        'Email ou mot de passe incorrect.',
      );
    }

    // Le rôle est relu depuis SQLite.
    // Si l'admin a accepté la demande RESTO,
    // le compte retournera désormais role = RESTO.
    return _publicUser(user);
  }

  // ============================================================
  // RECUPERER UN UTILISATEUR PAR ID
  // ============================================================

  Future<Map<String, Object?>?> getUserById(int id) async {
    final db = await _db;

    final rows = await db.query(
      'users',
      where: 'id = ? AND actif = 1',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _publicUser(rows.single);
  }

  // ============================================================
  // CONSULTER LE STATUT D'UNE DEMANDE RESTO
  // ============================================================

  Future<Map<String, Object?>?> getRestoRequestStatus(
    int userId,
  ) async {
    final db = await _db;

    final rows = await db.rawQuery(
      '''
      SELECT id, user_id, requested_role, status, submitted_at,
             reviewed_at, admin_id
      FROM restaurant_access_requests
      WHERE user_id = ?
      ORDER BY submitted_at DESC, id DESC
      LIMIT 1
      ''',
      [userId],
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.single;
  }

  Future<void> submitRestaurantAccessRequest({
    required int userId,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final users = await txn.query(
        'users',
        columns: ['id', 'nom', 'prenom', 'email'],
        where: "id = ? AND role = 'CLIENT' AND actif = 1",
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty) {
        throw StateError('Un compte client actif est requis.');
      }

      final pending = await txn.query(
        'restaurant_access_requests',
        columns: ['id'],
        where: "user_id = ? AND status = 'pending'",
        whereArgs: [userId],
        limit: 1,
      );
      if (pending.isNotEmpty) {
        throw StateError('Une demande est déjà en attente.');
      }

      final user = users.single;
      await _insertRestaurantAccessRequest(
        txn,
        userId,
        '${user['prenom']} ${user['nom']}',
        user['email'] as String,
      );
    });
  }

  Future<void> _insertRestaurantAccessRequest(
    DatabaseExecutor database,
    int userId,
    String name,
    String email,
  ) async {
    await database.insert('restaurant_access_requests', {
      'user_id': userId,
      'user_name': name.trim(),
      'user_email': email.trim().toLowerCase(),
      'requested_role': 'restaurant',
      'status': 'pending',
      'submitted_at': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // MODIFICATION DU MOT DE PASSE
  // ============================================================

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _db;

    final rows = await db.query(
      'users',
      where: 'id = ? AND actif = 1',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception(
        'Compte introuvable ou désactivé.',
      );
    }

    final previousHash = rows.single['password_hash'] as String;

    // Vérifier l'ancien mot de passe
    if (!BCrypt.checkpw(
      currentPassword,
      previousHash,
    )) {
      throw Exception(
        'Mot de passe actuel incorrect.',
      );
    }

    // Vérifier le nouveau mot de passe
    final problem = validatePassword(newPassword);

    if (problem != null) {
      throw Exception(problem);
    }

    // Empêcher la réutilisation du même mot de passe
    if (BCrypt.checkpw(
      newPassword,
      previousHash,
    )) {
      throw Exception(
        'Choisissez un mot de passe différent.',
      );
    }

    // Enregistrer le nouveau hash
    await db.update(
      'users',
      {
        'password_hash': BCrypt.hashpw(
          newPassword,
          BCrypt.gensalt(),
        ),
      },
      where: 'id = ? AND password_hash = ?',
      whereArgs: [
        userId,
        previousHash,
      ],
    );
  }
}
