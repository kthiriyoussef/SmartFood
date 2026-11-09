import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/purchase.dart';

class PurchaseRepository {
  PurchaseRepository({Database? database}) : _database = database;
  final Database? _database;
  Future<Database> get _db async =>
      _database ?? await DatabaseHelper.instance.database;
  Future<int> create(Purchase purchase) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert('achats', {
        'fournisseur_id': purchase.supplierId,
        'restaurant_id': purchase.restaurantId,
        'date_achat': purchase.date.toIso8601String(),
        'date_livraison_prevue': purchase.expectedDate.toIso8601String(),
        'statut': purchase.status,
        'total': purchase.total,
      });
      for (final line in purchase.lines) {
        await txn.insert('lignes_achat', line.toMap(id));
      }
      return id;
    });
  }

  Future<void> receive(int id) async {
    final db = await _db;
    final count = await db.update(
      'achats',
      {'statut': 'recu'},
      where: 'id = ? AND statut = ?',
      whereArgs: [id, 'en_attente'],
    );
    if (count == 0) {
      throw StateError('Cet achat ne peut pas être marqué comme reçu.');
    }
  }

  Future<List<Map<String, Object?>>> all({int? restaurantId}) async =>
      (await _db).rawQuery(
        'SELECT a.*, f.nom AS fournisseur, r.nom AS restaurant FROM achats a JOIN fournisseurs f ON f.id=a.fournisseur_id JOIN restaurants r ON r.id=a.restaurant_id WHERE (? IS NULL OR a.restaurant_id = ?) ORDER BY date_achat DESC',
        [restaurantId, restaurantId],
      );
  Future<int> pendingCount({int? restaurantId}) async =>
      Sqflite.firstIntValue(
        await (await _db).rawQuery(
          "SELECT COUNT(*) FROM achats WHERE statut='en_attente' AND (? IS NULL OR restaurant_id = ?)",
          [restaurantId, restaurantId],
        ),
      ) ??
      0;
}
