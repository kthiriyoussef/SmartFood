import 'package:sqflite/sqflite.dart';

import '../../../core/database/data_changes.dart';
import '../../../core/database/database_helper.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';

class SaleRepository {
  SaleRepository({Database? database}) : _database = database;
  final Database? _database;
  Future<Database> get _db async =>
      _database ?? await DatabaseHelper.instance.database;

  Future<int> create(Sale sale) async {
    SaleService.validate(sale);
    final db = await _db;
    return db.transaction((txn) async {
      await _validateDishes(txn, sale);
      final id = await txn.insert('ventes', {
        'restaurant_id': sale.restaurantId,
        'date_vente': sale.date.toIso8601String(),
        'mode_paiement': sale.paymentMode,
        'montant_recu': sale.amountReceived,
        'statut': sale.status,
        'total': sale.total,
        'client_user_id': sale.clientUserId,
        'sous_total': sale.subtotal,
        'remise': sale.discount,
        'taux_remise': sale.discountPercent,
      });
      for (final line in sale.lines) {
        await txn.insert('lignes_vente', line.toMap(id));
      }
      return id;
    });
  }

  Future<void> updatePending(int id, Sale sale) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'ventes',
        columns: ['statut'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty || rows.first['statut'] != 'en_attente') {
        throw StateError('Seule une vente en attente peut être modifiée.');
      }
      SaleService.validate(sale);
      await _validateDishes(txn, sale);
      await txn.update(
        'ventes',
        {
          'restaurant_id': sale.restaurantId,
          'date_vente': sale.date.toIso8601String(),
          'total': sale.total,
          'sous_total': sale.subtotal,
          'remise': sale.discount,
          'taux_remise': sale.discountPercent,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('lignes_vente', where: 'vente_id = ?', whereArgs: [id]);
      for (final line in sale.lines) {
        await txn.insert('lignes_vente', line.toMap(id));
      }
    });
  }

  Future<void> _validateDishes(Transaction txn, Sale sale) async {
    for (final line in sale.lines) {
      final rows = await txn.query(
        'menus',
        columns: ['nom', 'prix', 'restaurant_id', 'disponible', 'quantite'],
        where: 'id = ?',
        whereArgs: [line.dishId],
      );
      if (rows.isEmpty ||
          rows.first['restaurant_id'] != sale.restaurantId ||
          rows.first['disponible'] != 1 ||
          (rows.first['quantite'] as num).toInt() <= 0) {
        throw ArgumentError(
          'Ce plat n’est pas disponible dans le restaurant choisi.',
        );
      }
      if (rows.first['nom'] != line.designation ||
          ((rows.first['prix'] as num) * 1000).round() != line.unitPrice) {
        throw ArgumentError(
          'Le prix ou le nom du plat a changé. Sélectionnez-le à nouveau.',
        );
      }
    }
  }

  Future<void> pay(int id, String mode, int received) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT total, statut, restaurant_id FROM ventes WHERE id = ?',
        [id],
      );
      if (rows.isEmpty || rows.first['statut'] != 'en_attente') {
        throw StateError('Cette vente ne peut pas être payée.');
      }
      final total = rows.first['total']! as int;
      if ((mode == 'especes' && received < total) ||
          (mode != 'especes' && received != total)) {
        throw ArgumentError('Montant reçu invalide.');
      }
      final restaurantId = rows.first['restaurant_id']! as int;
      final lines = await txn.query(
        'lignes_vente',
        where: 'vente_id = ?',
        whereArgs: [id],
      );
      for (final line in lines) {
        final quantity = (line['quantite'] as num).toDouble();
        if (quantity <= 0 || quantity % 1 != 0) {
          throw ArgumentError('La quantité vendue doit être un nombre entier.');
        }
        final menuId = line['menu_id'] as int?;
        if (menuId == null) {
          throw StateError(
            'Un plat de cette vente n’existe plus dans la carte.',
          );
        }
        final changed = await txn.rawUpdate(
          '''UPDATE menus
             SET quantite = quantite - ?,
                 disponible = CASE WHEN quantite - ? <= 0 THEN 0 ELSE disponible END
             WHERE id = ? AND restaurant_id = ? AND disponible = 1 AND quantite >= ?''',
          [
            quantity.toInt(),
            quantity.toInt(),
            menuId,
            restaurantId,
            quantity.toInt(),
          ],
        );
        if (changed == 0) {
          throw StateError('Stock insuffisant pour terminer cette vente.');
        }
      }
      await txn.update(
        'ventes',
        {'mode_paiement': mode, 'montant_recu': received, 'statut': 'payee'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    DataChanges.catalogChanged();
  }

  Future<void> cancel(int id, String reason) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError('Le motif d’annulation est obligatoire.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'ventes',
        columns: ['statut'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['statut'] == 'annulee') {
        throw StateError('Cette vente est introuvable ou déjà annulée.');
      }
      if (rows.first['statut'] == 'payee') {
        final lines = await txn.query(
          'lignes_vente',
          where: 'vente_id = ?',
          whereArgs: [id],
        );
        for (final line in lines) {
          final menuId = line['menu_id'] as int?;
          if (menuId == null) continue;
          final quantity = (line['quantite'] as num).toInt();
          await txn.rawUpdate(
            '''UPDATE menus
               SET quantite = quantite + ?,
                   disponible = CASE WHEN quantite + ? > 0 AND (
                     SELECT statut FROM restaurants WHERE id = menus.restaurant_id
                   ) = 'actif' THEN 1 ELSE disponible END
               WHERE id = ?''',
            [quantity, quantity, menuId],
          );
        }
      }
      await txn.update(
        'ventes',
        {'statut': 'annulee', 'motif_annulation': normalizedReason},
        where: 'id = ? AND statut != ?',
        whereArgs: [id, 'annulee'],
      );
    });
    DataChanges.catalogChanged();
  }

  Future<List<Map<String, Object?>>> all({int? restaurantId}) async =>
      (await _db).rawQuery(
        'SELECT v.*, r.nom AS restaurant FROM ventes v JOIN restaurants r ON r.id=v.restaurant_id WHERE (? IS NULL OR v.restaurant_id = ?) ORDER BY date_vente DESC',
        [restaurantId, restaurantId],
      );
  Future<List<Map<String, Object?>>> forClient(int clientUserId) async =>
      (await _db).rawQuery(
        'SELECT v.*, r.nom AS restaurant FROM ventes v JOIN restaurants r ON r.id=v.restaurant_id WHERE v.client_user_id=? ORDER BY date_vente DESC',
        [clientUserId],
      );
  Future<int> todayTotal(DateTime date) async {
    final key = date.toIso8601String().substring(0, 10);
    final rows = await (await _db).rawQuery(
      "SELECT COALESCE(SUM(total),0) AS total FROM ventes WHERE substr(date_vente,1,10)=? AND statut='payee'",
      [key],
    );
    return rows.first['total']! as int;
  }

  Future<Map<String, int>> salesSummary(
    int restaurantId,
    DateTime start,
    DateTime end,
  ) async {
    final startDate = DateTime(
      start.year,
      start.month,
      start.day,
    ).toIso8601String().substring(0, 10);
    final endDate = DateTime(
      end.year,
      end.month,
      end.day,
    ).toIso8601String().substring(0, 10);
    final rows = await (await _db).rawQuery(
      "SELECT COALESCE(SUM(total),0) AS total, COUNT(*) AS count FROM ventes WHERE restaurant_id = ? AND substr(date_vente,1,10) BETWEEN ? AND ? AND statut='payee'",
      [restaurantId, startDate, endDate],
    );
    final total = rows.first['total']! as int;
    final count = rows.first['count']! as int;
    return {
      'total': total,
      'count': count,
      'average': count == 0 ? 0 : (total / count).round(),
    };
  }
}
