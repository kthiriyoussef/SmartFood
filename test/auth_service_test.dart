import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bcrypt/bcrypt.dart';

import 'package:smartfood/features/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late AuthService auth;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'CLIENT',
        restaurant_id INTEGER,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE restaurant_access_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        user_email TEXT NOT NULL,
        requested_role TEXT NOT NULL DEFAULT 'restaurant',
        status TEXT NOT NULL DEFAULT 'pending',
        submitted_at TEXT NOT NULL,
        reviewed_at TEXT,
        admin_id INTEGER
      )
    ''');

    auth = AuthService.forTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tests inscription', () {
    test('Inscription client réussie', () async {
      final user = await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );

      expect(user['email'], 'client@test.com');
      expect(user['role'], 'CLIENT');
      expect(user['restaurant_id'], isNull);
      expect(user['actif'], 1);
      expect(user.containsKey('password_hash'), false);
    });

    test('Inscription restaurant creates a pending request, not a role',
        () async {
      final user = await auth.register(
        nom: 'Test',
        prenom: 'Restaurant',
        email: 'owner@test.com',
        password: 'Password123!',
        requestRestaurantAccess: true,
      );

      expect(user['role'], 'CLIENT');
      expect(user['restaurant_id'], isNull);
      final requests = await db.query(
        'restaurant_access_requests',
        where: 'user_id = ?',
        whereArgs: [user['id']],
      );
      expect(requests, hasLength(1));
      expect(requests.single['requested_role'], 'restaurant');
      expect(requests.single['user_name'], 'Restaurant Test');
      expect(requests.single['user_email'], 'owner@test.com');
      expect(requests.single['status'], 'pending');
      expect(requests.single['admin_id'], isNull);
    });

    test('Customer registration does not create an access request', () async {
      await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );

      expect(await db.query('restaurant_access_requests'), isEmpty);
    });

    test('A user cannot create duplicate pending requests', () async {
      final user = await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );
      final userId = user['id'] as int;
      await auth.submitRestaurantAccessRequest(userId: userId);

      await expectLater(
        auth.submitRestaurantAccessRequest(userId: userId),
        throwsStateError,
      );
    });

    test('Email déjà utilisé refusé', () async {
      await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );

      await expectLater(
        auth.register(
          nom: 'Autre',
          prenom: 'Client',
          email: 'CLIENT@TEST.COM',
          password: 'Password456!',
        ),
        throwsException,
      );
    });

    test('Email invalide refusé', () async {
      await expectLater(
        auth.register(
          nom: 'Test',
          prenom: 'Client',
          email: 'email-invalide',
          password: 'Password123!',
        ),
        throwsException,
      );
    });

    test('Mot de passe trop court refusé', () async {
      await expectLater(
        auth.register(
          nom: 'Test',
          prenom: 'Client',
          email: 'client@test.com',
          password: '123',
        ),
        throwsException,
      );
    });
  });

  group('Tests connexion', () {
    setUp(() async {
      await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );
    });

    test('Connexion réussie', () async {
      final user = await auth.login(
        'client@test.com',
        'Password123!',
      );

      expect(user['email'], 'client@test.com');
      expect(user['role'], 'CLIENT');
      expect(user.containsKey('password_hash'), false);
    });

    test('Mot de passe incorrect refusé', () async {
      await expectLater(
        auth.login('client@test.com', 'MauvaisPassword'),
        throwsException,
      );
    });

    test('Compte inexistant refusé', () async {
      await expectLater(
        auth.login('inconnu@test.com', 'Password123!'),
        throwsException,
      );
    });

    test('Compte désactivé refusé', () async {
      await db.update(
        'users',
        {'actif': 0},
        where: 'email = ?',
        whereArgs: ['client@test.com'],
      );

      await expectLater(
        auth.login('client@test.com', 'Password123!'),
        throwsException,
      );
    });

    test('Récupération du compte actif', () async {
      final user = await auth.login(
        'client@test.com',
        'Password123!',
      );

      final id = user['id'] as int;
      final restored = await auth.getUserById(id);

      expect(restored, isNotNull);
      expect(restored!['email'], 'client@test.com');
      expect(restored.containsKey('password_hash'), false);
    });
  });

  group('Tests modification mot de passe', () {
    late int userId;

    setUp(() async {
      final user = await auth.register(
        nom: 'Test',
        prenom: 'Client',
        email: 'client@test.com',
        password: 'Password123!',
      );

      userId = user['id'] as int;
    });

    test('Modification réussie', () async {
      await auth.changePassword(
        userId: userId,
        currentPassword: 'Password123!',
        newPassword: 'NewPassword456!',
      );

      final user = await auth.login(
        'client@test.com',
        'NewPassword456!',
      );

      expect(user['id'], userId);

      await expectLater(
        auth.login('client@test.com', 'Password123!'),
        throwsException,
      );
    });

    test('Ancien mot de passe incorrect', () async {
      await expectLater(
        auth.changePassword(
          userId: userId,
          currentPassword: 'Incorrect123!',
          newPassword: 'NewPassword456!',
        ),
        throwsException,
      );
    });

    test('Nouveau mot de passe identique refusé', () async {
      await expectLater(
        auth.changePassword(
          userId: userId,
          currentPassword: 'Password123!',
          newPassword: 'Password123!',
        ),
        throwsException,
      );
    });

    test('Nouveau mot de passe trop court refusé', () async {
      await expectLater(
        auth.changePassword(
          userId: userId,
          currentPassword: 'Password123!',
          newPassword: '123',
        ),
        throwsException,
      );
    });

    test('Mot de passe stocké avec bcrypt', () async {
      final rows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      final hash = rows.single['password_hash'] as String;

      expect(hash, isNot('Password123!'));
      expect(BCrypt.checkpw('Password123!', hash), true);
    });
  });
}
