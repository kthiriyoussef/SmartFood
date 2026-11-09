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
  // RECUPERER LES RESTAURANTS ACTIFS
  // ============================================================

  Future<List<Map<String, Object?>>> getActiveRestaurants() async {
    final db = await _db;

    return db.query(
      'restaurants',
      columns: ['id', 'nom'],
      where: "statut = 'actif'",
      orderBy: 'nom ASC',
    );
  }

  // ============================================================
  // INSCRIPTION CLIENT OU DEMANDE RESTO
  // ============================================================

  Future<Map<String, Object?>> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    bool requestResto = false,
    int? restaurantId,
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

    // Si l'utilisateur demande RESTO,
    // il doit sélectionner un restaurant.
    if (requestResto && restaurantId == null) {
      throw Exception(
        'Veuillez sélectionner un restaurant.',
      );
    }

    // Hash sécurisé du mot de passe
    final passwordHash = BCrypt.hashpw(
      password,
      BCrypt.gensalt(),
    );

    // Transaction : compte + demande RESTO
    // sont enregistrés ensemble.
    final userId = await db.transaction<int>((txn) async {
      if (requestResto) {
        // Vérifier que le restaurant existe et est actif.
        final restaurants = await txn.query(
          'restaurants',
          columns: ['id'],
          where: "id = ? AND statut = 'actif'",
          whereArgs: [restaurantId],
          limit: 1,
        );

        if (restaurants.isEmpty) {
          throw Exception(
            'Restaurant introuvable ou inactif.',
          );
        }
      }

      // Le compte est toujours créé avec le rôle CLIENT.
      // Seul l'administrateur pourra accorder RESTO.
      final id = await txn.insert('users', {
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'email': normalized,
        'password_hash': passwordHash,
        'role': 'CLIENT',
        'restaurant_id': null,
        'actif': 1,
      });

      // Créer une demande RESTO si nécessaire.
      if (requestResto) {
        await txn.insert(
          'restaurant_role_requests',
          {
            'user_id': id,
            'restaurant_id': restaurantId,
            'statut': 'EN_ATTENTE',
            'date_demande': DateTime.now().toIso8601String(),
            'date_decision': null,
            'admin_id': null,
          },
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

    final rows = await db.query(
      'restaurant_role_requests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.single;
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
