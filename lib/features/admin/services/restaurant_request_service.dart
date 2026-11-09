import 'package:smartfood/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class RestaurantRequestService {
  Future<void> _requireAdmin(
    DatabaseExecutor db,
    int actorId,
  ) async {
    final admins = await db.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'ADMIN' AND actif = 1",
      whereArgs: [actorId],
      limit: 1,
    );

    if (admins.isEmpty) {
      throw Exception('Accès réservé aux administrateurs.');
    }
  }

  Future<List<Map<String, Object?>>> listRequests({
    required int actorId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await _requireAdmin(db, actorId);

    return db.rawQuery('''
      SELECT
        req.id,
        req.user_id,
        req.restaurant_id,
        req.statut,
        req.date_demande,
        req.date_decision,
        u.nom,
        u.prenom,
        u.email,
        r.nom AS restaurant_nom
      FROM restaurant_role_requests req
      INNER JOIN users u ON u.id = req.user_id
      INNER JOIN restaurants r ON r.id = req.restaurant_id
      ORDER BY
        CASE WHEN req.statut = 'EN_ATTENTE' THEN 0 ELSE 1 END,
        req.date_demande DESC,
        req.id DESC
    ''');
  }

  Future<int> pendingCount({
    required int actorId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await _requireAdmin(db, actorId);

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM restaurant_role_requests
      WHERE statut = 'EN_ATTENTE'
    ''');

    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> decide({
    required int actorId,
    required int requestId,
    required bool accept,
  }) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await _requireAdmin(txn, actorId);

      final requests = await txn.query(
        'restaurant_role_requests',
        where: 'id = ?',
        whereArgs: [requestId],
        limit: 1,
      );

      if (requests.isEmpty) {
        throw Exception('Demande introuvable.');
      }

      final request = requests.single;

      if (request['statut'] != 'EN_ATTENTE') {
        throw Exception('Cette demande a déjà été traitée.');
      }

      final userId = request['user_id'] as int;
      final restaurantId = request['restaurant_id'] as int;

      final users = await txn.query(
        'users',
        columns: ['id', 'role', 'actif'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (users.isEmpty ||
          users.single['actif'] != 1 ||
          users.single['role'] != 'CLIENT') {
        throw Exception(
          'Le compte doit être un client actif.',
        );
      }

      if (accept) {
        final restaurants = await txn.query(
          'restaurants',
          columns: ['id'],
          where: "id = ? AND statut = 'actif'",
          whereArgs: [restaurantId],
          limit: 1,
        );

        if (restaurants.isEmpty) {
          throw Exception(
            'Le restaurant est introuvable ou archivé.',
          );
        }

        final updated = await txn.update(
          'users',
          {
            'role': 'RESTO',
            'restaurant_id': restaurantId,
          },
          where: "id = ? AND role = 'CLIENT' AND actif = 1",
          whereArgs: [userId],
        );

        if (updated != 1) {
          throw Exception('Impossible de modifier le compte.');
        }
      }

      final changed = await txn.update(
        'restaurant_role_requests',
        {
          'statut': accept ? 'ACCEPTEE' : 'REFUSEE',
          'date_decision': DateTime.now().toIso8601String(),
          'admin_id': actorId,
        },
        where: "id = ? AND statut = 'EN_ATTENTE'",
        whereArgs: [requestId],
      );

      if (changed != 1) {
        throw Exception('Impossible de traiter la demande.');
      }
    });
  }
}
