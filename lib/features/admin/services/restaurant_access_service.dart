import 'package:smartfood/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class RestaurantAccessService {
  RestaurantAccessService({Database? testDatabase})
      : _testDatabase = testDatabase;

  final Database? _testDatabase;

  Future<Database> get _database async =>
      _testDatabase ?? await DatabaseHelper.instance.database;

  Future<void> _requireAdmin(DatabaseExecutor database, int actorId) async {
    final admins = await database.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'ADMIN' AND actif = 1",
      whereArgs: [actorId],
      limit: 1,
    );
    if (admins.isEmpty) {
      throw StateError('Accès réservé aux administrateurs.');
    }
  }

  Future<List<Map<String, Object?>>> listRequests({
    required int actorId,
  }) async {
    final database = await _database;
    await _requireAdmin(database, actorId);

    return database.rawQuery('''
      SELECT
        req.id,
        req.user_id,
        req.requested_role,
        req.status,
        req.submitted_at,
        req.reviewed_at,
        req.admin_id,
        req.user_name,
        req.user_email,
        reviewer.nom AS reviewer_nom,
        reviewer.prenom AS reviewer_prenom
      FROM restaurant_access_requests req
      LEFT JOIN users reviewer ON reviewer.id = req.admin_id
      ORDER BY
        CASE WHEN req.status = 'pending' THEN 0 ELSE 1 END,
        req.submitted_at DESC,
        req.id DESC
    ''');
  }

  Future<int> pendingCount({required int actorId}) async {
    final database = await _database;
    await _requireAdmin(database, actorId);

    final result = await database.rawQuery('''
      SELECT COUNT(*) AS total
      FROM restaurant_access_requests
      WHERE status = 'pending'
    ''');
    return (result.single['total'] as num).toInt();
  }

  Future<void> decide({
    required int actorId,
    required int requestId,
    required bool approve,
  }) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await _requireAdmin(transaction, actorId);

      final requests = await transaction.query(
        'restaurant_access_requests',
        where: 'id = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (requests.isEmpty) {
        throw StateError('Demande introuvable.');
      }

      final request = requests.single;
      if (request['status'] != 'pending') {
        throw StateError('Cette demande a déjà été traitée.');
      }

      final userId = request['user_id'] as int;
      if (userId == actorId) {
        throw StateError('Un administrateur ne peut pas traiter sa propre demande.');
      }

      final users = await transaction.query(
        'users',
        columns: ['id'],
        where: "id = ? AND role = 'CLIENT' AND actif = 1",
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty) {
        throw StateError('Le compte demandeur doit être un client actif.');
      }

      if (approve) {
        final updated = await transaction.update(
          'users',
          {'role': 'RESTO'},
          where: "id = ? AND role = 'CLIENT' AND actif = 1",
          whereArgs: [userId],
        );
        if (updated != 1) {
          throw StateError('Impossible d’autoriser ce compte.');
        }
      }

      final updatedRequest = await transaction.update(
        'restaurant_access_requests',
        {
          'status': approve ? 'approved' : 'rejected',
          'reviewed_at': DateTime.now().toIso8601String(),
          'admin_id': actorId,
        },
        where: "id = ? AND status = 'pending'",
        whereArgs: [requestId],
      );
      if (updatedRequest != 1) {
        throw StateError('Impossible de traiter la demande.');
      }
    });
  }
}
