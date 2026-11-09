import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartfood/core/database/database_schema.dart';
import 'package:smartfood/features/purchases/models/purchase.dart';
import 'package:smartfood/features/purchases/repositories/purchase_repository.dart';
import 'package:smartfood/features/sales/models/sale.dart';
import 'package:smartfood/features/sales/repositories/sale_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: DatabaseSchema.create,
      ),
    );
    final now = DateTime(2026, 11, 9).toIso8601String();
    await database.insert('restaurants', {
      'id': 1,
      'nom': 'Restaurant test',
      'adresse': 'Rue test',
      'ville': 'Tunis',
      'telephone': '00000000',
      'statut': 'actif',
      'date_creation': now,
    });
    await database.insert('users', {
      'id': 1,
      'nom': 'Client',
      'prenom': 'Test',
      'email': 'client@example.test',
      'password_hash': 'test-hash',
      'role': 'CLIENT',
      'restaurant_id': null,
      'actif': 1,
    });
    await database.insert('menus', {
      'id': 1,
      'restaurant_id': 1,
      'nom': 'Plat test',
      'description': 'Description',
      'prix': 30.0,
      'categorie': 'Plat',
      'quantite': 5,
      'disponible': 1,
      'date_creation': now,
    });
    await database.insert('fournisseurs', {'id': 1, 'nom': 'Fournisseur test'});
  });

  tearDown(() => database.close());

  test(
    'vente client, paiement, stock et annulation sont enregistrés',
    () async {
      final repository = SaleRepository(database: database);
      final sale = Sale(
        restaurantId: 1,
        clientUserId: 1,
        date: DateTime(2026, 11, 9),
        lines: const [
          SaleLine(
            designation: 'Plat test',
            quantity: 2,
            unitPrice: 30000,
            dishId: 1,
          ),
        ],
      );

      final saleId = await repository.create(sale);
      expect(sale.subtotal, 60000);
      expect(sale.discount, 6000);
      expect(sale.total, 54000);
      await repository.pay(saleId, 'carte', sale.total);

      var menu = (await database.query(
        'menus',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(menu['quantite'], 3);
      var storedSale = (await database.query(
        'ventes',
        where: 'id = ?',
        whereArgs: [saleId],
      )).single;
      expect(storedSale['statut'], 'payee');
      expect(storedSale['client_user_id'], 1);

      await repository.cancel(saleId, 'Commande annulée par le client');
      menu = (await database.query(
        'menus',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      storedSale = (await database.query(
        'ventes',
        where: 'id = ?',
        whereArgs: [saleId],
      )).single;
      expect(menu['quantite'], 5);
      expect(storedSale['statut'], 'annulee');
      expect(storedSale['motif_annulation'], 'Commande annulée par le client');
      expect(
        (await repository.salesSummary(
          1,
          DateTime(2026, 11, 9),
          DateTime(2026, 11, 9),
        ))['count'],
        0,
      );
    },
  );

  test('paiement bloqué si le stock est devenu insuffisant', () async {
    final repository = SaleRepository(database: database);
    final saleId = await repository.create(
      Sale(
        restaurantId: 1,
        date: DateTime(2026, 11, 9),
        lines: const [
          SaleLine(
            designation: 'Plat test',
            quantity: 6,
            unitPrice: 30000,
            dishId: 1,
          ),
        ],
      ),
    );

    await expectLater(
      repository.pay(saleId, 'carte', 162000),
      throwsA(isA<StateError>()),
    );
    final menu = (await database.query(
      'menus',
      where: 'id = ?',
      whereArgs: [1],
    )).single;
    final storedSale = (await database.query(
      'ventes',
      where: 'id = ?',
      whereArgs: [saleId],
    )).single;
    expect(menu['quantite'], 5);
    expect(storedSale['statut'], 'en_attente');
  });

  test('achat fournisseur est enregistré et marqué reçu', () async {
    final repository = PurchaseRepository(database: database);
    final purchaseId = await repository.create(
      Purchase(
        supplierId: 1,
        restaurantId: 1,
        date: DateTime(2026, 11, 9),
        expectedDate: DateTime(2026, 11, 10),
        lines: const [
          PurchaseLine(
            designation: 'Farine',
            quantity: 10,
            unit: 'kg',
            unitPrice: 1200,
          ),
        ],
      ),
    );
    await repository.receive(purchaseId);

    final purchase = (await database.query(
      'achats',
      where: 'id = ?',
      whereArgs: [purchaseId],
    )).single;
    expect(purchase['statut'], 'recu');
    expect(purchase['total'], 12000);
    expect(
      await database.query(
        'lignes_achat',
        where: 'achat_id = ?',
        whereArgs: [purchaseId],
      ),
      hasLength(1),
    );
  });
}
