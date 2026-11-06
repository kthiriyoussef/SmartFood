import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smartfood/features/reclamation/repositories/reclamation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ReclamationRepository repository;

  const clientId = 1;
  const adminId = 2;
  const autreClientId = 3;

  setUp(() async {
    // Base temporaire : aucune donnée réelle n'est modifiée.
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
        role TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE reclamations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        sujet TEXT NOT NULL,
        description TEXT NOT NULL,
        reservation_ref TEXT,
        statut TEXT NOT NULL DEFAULT 'EN_ATTENTE',
        priorite TEXT NOT NULL DEFAULT 'MOYENNE',
        impact TEXT NOT NULL DEFAULT 'NORMAL',
        justificatif_path TEXT,
        justificatif_name TEXT,
        date_creation TEXT NOT NULL,
        date_modification TEXT
      )
    ''');

    await db.insert('users', {
      'id': clientId,
      'nom': 'Client',
      'prenom': 'Test',
      'email': 'client@test.local',
      'password_hash': 'test',
      'role': 'CLIENT',
      'actif': 1,
    });

    await db.insert('users', {
      'id': adminId,
      'nom': 'Admin',
      'prenom': 'Test',
      'email': 'admin@test.local',
      'password_hash': 'test',
      'role': 'ADMIN',
      'actif': 1,
    });

    await db.insert('users', {
      'id': autreClientId,
      'nom': 'Autre',
      'prenom': 'Client',
      'email': 'autre@test.local',
      'password_hash': 'test',
      'role': 'CLIENT',
      'actif': 1,
    });

    repository = ReclamationRepository(
      testDatabase: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Calcul automatique des priorités', () {
    final now = DateTime(2026, 11, 6, 12);

    test('Autre + NORMAL = FAIBLE', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Autre',
        impact: 'NORMAL',
        createdAt: now,
        now: now,
      );

      expect(result, 'FAIBLE');
    });

    test('Quantité incorrecte + NORMAL = MOYENNE', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Quantité incorrecte',
        impact: 'NORMAL',
        createdAt: now,
        now: now,
      );

      expect(result, 'MOYENNE');
    });

    test('Plat non conforme + NORMAL = ELEVEE', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Plat non conforme',
        impact: 'NORMAL',
        createdAt: now,
        now: now,
      );

      expect(result, 'ELEVEE');
    });

    test('Commande payée non reçue = URGENTE', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Commande payée non reçue',
        impact: 'NORMAL',
        createdAt: now,
        now: now,
      );

      expect(result, 'URGENTE');
    });

    test('Impact FORT augmente la priorité', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Quantité incorrecte',
        impact: 'FORT',
        createdAt: now,
        now: now,
      );

      expect(result, 'ELEVEE');
    });

    test('Après 72 heures la priorité augmente', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Plat non conforme',
        impact: 'NORMAL',
        createdAt: now.subtract(
          const Duration(hours: 72),
        ),
        now: now,
      );

      expect(result, 'URGENTE');
    });

    test('Avant 72 heures la priorité ne change pas', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Plat non conforme',
        impact: 'NORMAL',
        createdAt: now.subtract(
          const Duration(hours: 71),
        ),
        now: now,
      );

      expect(result, 'ELEVEE');
    });

    test('La priorité ne dépasse jamais URGENTE', () {
      final result = ReclamationRepository.calculatePriority(
        sujet: 'Commande payée non reçue',
        impact: 'FORT',
        createdAt: now.subtract(
          const Duration(days: 10),
        ),
        now: now,
      );

      expect(result, 'URGENTE');
    });
  });

  group('Création et consultation des réclamations', () {
    test('CLIENT crée une réclamation urgente', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Commande payée non reçue',
        description: 'Commande payée mais jamais reçue.',
        impact: 'FORT',
      );

      final rows = await db.query(
        'reclamations',
        where: 'id = ?',
        whereArgs: [id],
      );

      expect(rows.length, 1);
      expect(rows.first['priorite'], 'URGENTE');
      expect(rows.first['impact'], 'FORT');
      expect(rows.first['statut'], 'EN_ATTENTE');
      expect(rows.first['user_id'], clientId);
    });

    test('CLIENT consulte son historique', () async {
      await repository.create(
        userId: clientId,
        sujet: 'Autre',
        description: 'Un problème avec mon service.',
      );

      final history = await repository.history(
        userId: clientId,
      );

      expect(history.length, 1);
      expect(history.first['priorite'], 'FAIBLE');
    });

    test('CLIENT consulte les détails de son ticket', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Plat non conforme',
        description: 'Le plat reçu ne correspond pas.',
      );

      final details = await repository.details(
        userId: clientId,
        reclamationId: id,
      );

      expect(details, isNotNull);
      expect(details!['priorite'], 'ELEVEE');
    });

    test('Description trop courte refusée', () async {
      await expectLater(
        repository.create(
          userId: clientId,
          sujet: 'Autre',
          description: 'Court',
        ),
        throwsArgumentError,
      );
    });

    test('Impact invalide refusé', () async {
      await expectLater(
        repository.create(
          userId: clientId,
          sujet: 'Autre',
          description: 'Description suffisamment longue.',
          impact: 'CRITIQUE',
        ),
        throwsArgumentError,
      );
    });
  });

  group('Sécurité CLIENT et ADMIN', () {
    test('ADMIN ne peut pas créer une réclamation client', () async {
      await expectLater(
        repository.create(
          userId: adminId,
          sujet: 'Autre',
          description: 'Une description de test valide.',
        ),
        throwsStateError,
      );
    });

    test('CLIENT ne peut pas accéder à la liste ADMIN', () async {
      await expectLater(
        repository.allForAdmin(
          adminId: clientId,
        ),
        throwsStateError,
      );
    });

    test('Un client ne peut pas voir le ticket d un autre', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Autre',
        description: 'Un problème de commande à vérifier.',
      );

      final result = await repository.details(
        userId: autreClientId,
        reclamationId: id,
      );

      expect(result, isNull);
    });

    test('CLIENT ne peut pas modifier un statut', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Autre',
        description: 'Un problème de commande à vérifier.',
      );

      await expectLater(
        repository.updateStatus(
          adminId: clientId,
          reclamationId: id,
          statut: 'RESOLUE',
        ),
        throwsStateError,
      );
    });
  });

  group('Traitement ADMIN', () {
    test('ADMIN voit les réclamations urgentes', () async {
      await repository.create(
        userId: clientId,
        sujet: 'Commande payée non reçue',
        description: 'Ma commande a été payée mais non reçue.',
        impact: 'FORT',
      );

      final rows = await repository.allForAdmin(
        adminId: adminId,
      );

      expect(rows.length, 1);
      expect(rows.first['priorite'], 'URGENTE');
    });

    test('ADMIN modifie le statut EN_COURS', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Plat non conforme',
        description: 'Le plat ne correspond pas à la commande.',
      );

      await repository.updateStatus(
        adminId: adminId,
        reclamationId: id,
        statut: 'EN_COURS',
      );

      final rows = await db.query(
        'reclamations',
        where: 'id = ?',
        whereArgs: [id],
      );

      expect(rows.first['statut'], 'EN_COURS');
    });

    test('ADMIN résout une réclamation', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Commande payée non reçue',
        description: 'La commande a été payée mais non reçue.',
        impact: 'FORT',
      );

      await repository.updateStatus(
        adminId: adminId,
        reclamationId: id,
        statut: 'RESOLUE',
      );

      final rows = await db.query(
        'reclamations',
        where: 'id = ?',
        whereArgs: [id],
      );

      expect(rows.first['statut'], 'RESOLUE');
    });

    test('Statut invalide refusé', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Autre',
        description: 'Une description de test suffisamment longue.',
      );

      await expectLater(
        repository.updateStatus(
          adminId: adminId,
          reclamationId: id,
          statut: 'INCONNU',
        ),
        throwsArgumentError,
      );
    });

    test('Les tickets urgents ouverts passent en premier', () async {
      await repository.create(
        userId: clientId,
        sujet: 'Autre',
        description: 'Une réclamation avec une priorité faible.',
      );

      await repository.create(
        userId: clientId,
        sujet: 'Commande payée non reçue',
        description: 'Une commande payée jamais reçue.',
        impact: 'FORT',
      );

      final rows = await repository.allForAdmin(
        adminId: adminId,
      );

      expect(rows.length, 2);
      expect(rows.first['priorite'], 'URGENTE');
      expect(rows.last['priorite'], 'FAIBLE');
    });

    test('Actualisation automatique après 72 heures', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Plat non conforme',
        description: 'Le plat reçu ne correspond pas à la commande.',
        impact: 'NORMAL',
      );

      final ancienneDate = DateTime.now().subtract(
        const Duration(hours: 73),
      );

      await db.update(
        'reclamations',
        {
          'date_creation': ancienneDate.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // La consultation ADMIN déclenche le recalcul.
      final rows = await repository.allForAdmin(
        adminId: adminId,
      );

      expect(rows.single['priorite'], 'URGENTE');
    });

    test('Un ticket résolu ne change plus de priorité', () async {
      final id = await repository.create(
        userId: clientId,
        sujet: 'Plat non conforme',
        description: 'Le plat reçu ne correspond pas à la commande.',
      );

      await repository.updateStatus(
        adminId: adminId,
        reclamationId: id,
        statut: 'RESOLUE',
      );

      await db.update(
        'reclamations',
        {
          'date_creation': DateTime.now()
              .subtract(const Duration(days: 5))
              .toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final rows = await repository.allForAdmin(
        adminId: adminId,
      );

      expect(rows.single['statut'], 'RESOLUE');
      expect(rows.single['priorite'], 'ELEVEE');
    });
  });
}
