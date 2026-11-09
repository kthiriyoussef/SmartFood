import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartfood/features/auth/services/auth_service.dart';
import 'package:smartfood/features/admin/services/restaurant_access_service.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/repositories/restaurant_repository.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late RestaurantAccessService accessService;
  late RestaurantService restaurantService;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL,
        password_hash TEXT,
        role TEXT NOT NULL,
        restaurant_id INTEGER,
        actif INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE restaurants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        adresse TEXT NOT NULL,
        ville TEXT NOT NULL,
        telephone TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'actif',
        date_creation TEXT NOT NULL
      )
    ''');
    await database.execute('''
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
    await database.insert('users', {
      'id': 1,
      'nom': 'Admin',
      'prenom': 'Test',
      'email': 'admin@test.local',
      'role': 'ADMIN',
      'actif': 1,
    });
    await database.insert('users', {
      'id': 2,
      'nom': 'Client',
      'prenom': 'Test',
      'email': 'client@test.local',
      'role': 'CLIENT',
      'actif': 1,
    });

    accessService = RestaurantAccessService(testDatabase: database);
    restaurantService = RestaurantService(
      repository: RestaurantRepository(testDatabase: database),
    );
  });

  tearDown(() async => database.close());

  Future<int> addPendingRequest() => database.insert(
        'restaurant_access_requests',
        {
          'user_id': 2,
          'user_name': 'Test Client',
          'user_email': 'client@test.local',
          'requested_role': 'restaurant',
          'status': 'pending',
          'submitted_at': DateTime(2026, 1, 1).toIso8601String(),
        },
      );

  test('admin approval grants role without creating a restaurant', () async {
    final requestId = await addPendingRequest();
    await accessService.decide(
      actorId: 1,
      requestId: requestId,
      approve: true,
    );

    final user = (await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [2],
    ))
        .single;
    final request = (await database.query(
      'restaurant_access_requests',
      where: 'id = ?',
      whereArgs: [requestId],
    ))
        .single;
    expect(user['role'], 'RESTO');
    expect(user['restaurant_id'], isNull);
    expect(request['status'], 'approved');
    expect(request['admin_id'], 1);
    expect(request['reviewed_at'], isNotNull);
    expect(await database.query('restaurants'), isEmpty);
    expect(
      await restaurantService.getPostLoginDestination(
        userId: 2,
        role: user['role'] as String,
      ),
      RestaurantPostLoginDestination.createRestaurant,
    );
  });

  test('restaurant signup request is visible and approval grants the role',
      () async {
    final auth = AuthService.forTesting(database);
    final user = await auth.register(
      nom: 'Owner',
      prenom: 'New',
      email: 'new-owner@test.local',
      password: 'Password123!',
      requestRestaurantAccess: true,
    );
    final userId = user['id'] as int;
    final request = await auth.getRestoRequestStatus(userId);

    expect(user['role'], 'CLIENT');
    expect(request?['status'], 'pending');
    expect(await accessService.pendingCount(actorId: 1), 1);
    final adminRequests = await accessService.listRequests(actorId: 1);
    expect(adminRequests.single['user_name'], 'New Owner');
    expect(adminRequests.single['user_email'], 'new-owner@test.local');

    await accessService.decide(
      actorId: 1,
      requestId: request!['id'] as int,
      approve: true,
    );
    expect((await auth.getUserById(userId))?['role'], 'RESTO');
    expect(await database.query('restaurants'), isEmpty);
  });

  test('restaurant creation associates the owner and next login routes home',
      () async {
    final requestId = await addPendingRequest();
    await accessService.decide(
      actorId: 1,
      requestId: requestId,
      approve: true,
    );
    final restaurantId =
        await restaurantService.sauvegarderRestaurantPourProprietaire(
      Restaurant(
        nom: 'Le Jardin',
        adresse: '10 rue du Centre',
        ville: 'Tunis',
        telephone: '+216 71 123 456',
        dateCreation: DateTime(2026, 1, 1),
      ),
      2,
    );

    final user = (await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [2],
    ))
        .single;
    expect(user['restaurant_id'], restaurantId);
    expect(
      await restaurantService.getPostLoginDestination(
        userId: 2,
        role: user['role'] as String,
      ),
      RestaurantPostLoginDestination.restaurantDashboard,
    );
  });

  test('owner cannot create a second associated restaurant', () async {
    final requestId = await addPendingRequest();
    await accessService.decide(
      actorId: 1,
      requestId: requestId,
      approve: true,
    );
    final restaurant = Restaurant(
      nom: 'Le Jardin',
      adresse: '10 rue du Centre',
      ville: 'Tunis',
      telephone: '+216 71 123 456',
      dateCreation: DateTime(2026, 1, 1),
    );
    await restaurantService.sauvegarderRestaurantPourProprietaire(
      restaurant,
      2,
    );

    await expectLater(
      restaurantService.sauvegarderRestaurantPourProprietaire(
        restaurant.copyWith(nom: 'Autre restaurant'),
        2,
      ),
      throwsA(isA<RestaurantValidationException>()),
    );
    expect(await database.query('restaurants'), hasLength(1));
  });

  test('normal user keeps the existing post-login flow', () async {
    expect(
      await restaurantService.getPostLoginDestination(
        userId: 2,
        role: 'CLIENT',
      ),
      RestaurantPostLoginDestination.existingRoleFlow,
    );
    expect(
      await restaurantService.getPostLoginDestination(
        userId: 1,
        role: 'ADMIN',
      ),
      RestaurantPostLoginDestination.existingRoleFlow,
    );
  });

  test('non-admin cannot grant restaurant role', () async {
    final requestId = await addPendingRequest();
    await expectLater(
      accessService.decide(
        actorId: 2,
        requestId: requestId,
        approve: true,
      ),
      throwsStateError,
    );
  });

  test('admin rejection retains client role and permits a fresh request',
      () async {
    final requestId = await addPendingRequest();
    await accessService.decide(
      actorId: 1,
      requestId: requestId,
      approve: false,
    );

    final user = (await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [2],
    ))
        .single;
    final request = (await database.query(
      'restaurant_access_requests',
      where: 'id = ?',
      whereArgs: [requestId],
    ))
        .single;
    expect(user['role'], 'CLIENT');
    expect(request['status'], 'rejected');
    expect(request['admin_id'], 1);
    expect(request['reviewed_at'], isNotNull);

    await AuthService.forTesting(database).submitRestaurantAccessRequest(
      userId: 2,
    );
    expect(
      await database.query(
        'restaurant_access_requests',
        where: 'user_id = ? AND status = ?',
        whereArgs: [2, 'pending'],
      ),
      hasLength(1),
    );
  });
}
