import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';

class ReclamationMessageRepository {
  ReclamationMessageRepository({Database? testDatabase})
      : _testDatabase = testDatabase;

  final Database? _testDatabase;

  Future<Database> get _db async =>
      _testDatabase ?? await DatabaseHelper.instance.database;

  Future<void> _authorize(
    DatabaseExecutor db, {
    required int userId,
    required int reclamationId,
  }) async {
    final users = await db.query(
      'users',
      columns: ['role'],
      where: 'id = ? AND actif = 1',
      whereArgs: [userId],
      limit: 1,
    );

    if (users.isEmpty) {
      throw StateError('Compte utilisateur introuvable ou désactivé.');
    }

    final tickets = await db.query(
      'reclamations',
      columns: ['user_id'],
      where: 'id = ?',
      whereArgs: [reclamationId],
      limit: 1,
    );

    if (tickets.isEmpty) {
      throw StateError('Réclamation introuvable.');
    }

    final role = users.first['role'];

    if (role != 'ADMIN' &&
        !(role == 'CLIENT' && tickets.first['user_id'] == userId)) {
      throw StateError('Accès à cette conversation refusé.');
    }
  }

  Future<List<Map<String, Object?>>> messages({
    required int userId,
    required int reclamationId,
  }) async {
    final db = await _db;

    await _authorize(
      db,
      userId: userId,
      reclamationId: reclamationId,
    );

    return db.rawQuery('''
      SELECT m.id, m.reclamation_id, m.sender_id,
             m.message, m.date_envoi, m.date_lecture,
             u.prenom, u.nom, u.role AS sender_role
      FROM reclamation_messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.reclamation_id = ?
      ORDER BY m.date_envoi ASC, m.id ASC
    ''', [reclamationId]);
  }

  Future<int> send({
    required int userId,
    required int reclamationId,
    required String message,
  }) async {
    final content = message.trim();

    if (content.isEmpty) {
      throw ArgumentError('Le message est vide.');
    }

    if (content.length > 2000) {
      throw ArgumentError('Maximum 2000 caractères.');
    }

    final db = await _db;

    return db.transaction((txn) async {
      await _authorize(
        txn,
        userId: userId,
        reclamationId: reclamationId,
      );

      return txn.insert('reclamation_messages', {
        'reclamation_id': reclamationId,
        'sender_id': userId,
        'message': content,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> markRead({
    required int userId,
    required int reclamationId,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      await _authorize(
        txn,
        userId: userId,
        reclamationId: reclamationId,
      );

      await txn.update(
        'reclamation_messages',
        {
          'date_lecture': DateTime.now().toIso8601String(),
        },
        where: '''
          reclamation_id = ?
          AND sender_id != ?
          AND date_lecture IS NULL
        ''',
        whereArgs: [reclamationId, userId],
      );
    });
  }
}
