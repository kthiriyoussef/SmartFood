
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartfood/features/users/services/user_management_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late UserManagementService service;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE restaurants (
      id INTEGER PRIMARY KEY, nom TEXT NOT NULL,
      statut TEXT NOT NULL DEFAULT 'actif')''');
    await db.execute('''CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL, prenom TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL, role TEXT NOT NULL,
      restaurant_id INTEGER, actif INTEGER NOT NULL DEFAULT 1)''');
    await db.insert('restaurants',
      {'id': 1, 'nom': 'Restaurant test', 'statut': 'actif'});
    await db.insert('users', {
      'id': 1, 'nom': 'Admin', 'prenom': 'Test',
      'email': 'admin@test.local',
      'password_hash': BCrypt.hashpw('AdminPass123!', BCrypt.gensalt()),
      'role': 'ADMIN', 'actif': 1,
    });
    await db.insert('users', {
      'id': 2, 'nom': 'Client', 'prenom': 'Test',
      'email': 'client@test.local',
      'password_hash': BCrypt.hashpw('ClientPass123!', BCrypt.gensalt()),
      'role': 'CLIENT', 'actif': 1,
    });
    service = UserManagementService(testDatabase: db);
  });
  tearDown(() async => db.close());

  test('Admin crée un RESTO associé à un restaurant', () async {
    final id = await service.createUser(
      actorId: 1, nom: 'Resto', prenom: 'Chef',
      email: 'resto@test.local', password: 'RestoPass123!',
      role: 'RESTO', restaurantId: 1);
    final users = await service.listUsers(actorId: 1);
    final resto = users.singleWhere((u) => u['id'] == id);
    expect(resto['role'], 'RESTO');
    expect(resto['restaurant_id'], 1);
    expect(resto.containsKey('password_hash'), false);
  });

  test('CLIENT ne peut pas lire les comptes', () async {
    await expectLater(service.listUsers(actorId: 2), throwsStateError);
  });

  test('CLIENT ne peut pas créer de compte RESTO', () async {
    await expectLater(service.createUser(
      actorId: 2, nom: 'Resto', prenom: 'Chef',
      email: 'r@test.local', password: 'RestoPass123!',
      role: 'RESTO', restaurantId: 1), throwsStateError);
  });

  test('RESTO sans restaurant refusé', () async {
    await expectLater(service.createUser(
      actorId: 1, nom: 'Resto', prenom: 'Chef',
      email: 'r@test.local', password: 'RestoPass123!',
      role: 'RESTO'), throwsArgumentError);
  });

  test('Admin désactive et réactive un client', () async {
    await service.setActive(actorId: 1, userId: 2, active: false);
    expect((await service.listUsers(actorId: 1))
      .singleWhere((u) => u['id'] == 2)['actif'], 0);
    await service.setActive(actorId: 1, userId: 2, active: true);
    expect((await service.listUsers(actorId: 1))
      .singleWhere((u) => u['id'] == 2)['actif'], 1);
  });

  test('Admin ne peut pas se désactiver', () async {
    await expectLater(
      service.setActive(actorId: 1, userId: 1, active: false),
      throwsStateError);
  });

  test('Statistiques cohérentes', () async {
    final stats = await service.statistics(actorId: 1);
    expect(stats['total'], 2);
    expect(stats['active'], 2);
    expect(stats['restaurants'], 1);
  });
}
