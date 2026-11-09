import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';

/// Erreur métier levée par le repository (stock épuisé, plat retiré…).
class ReservationException implements Exception {
  const ReservationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReservationRepository {
  Future<Database> get _database => DatabaseHelper.instance.database;

  /// Crée la réservation ET décrémente le stock du plat dans une seule
  /// transaction : soit les deux réussissent, soit rien n'est enregistré.
  /// Le stock est relu dans la transaction, donc deux clients ne peuvent pas
  /// réserver la dernière portion en même temps.
  Future<Reservation> createWithStock(Reservation reservation) async {
    final menuId = reservation.menuId;
    if (menuId == null) {
      throw const ReservationException('Plat introuvable.');
    }

    final database = await _database;
    return database.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT m.quantite, m.disponible, r.statut AS restaurant_statut
        FROM menus m
        JOIN restaurants r ON r.id = m.restaurant_id
        WHERE m.id = ?
        ''',
        [menuId],
      );
      if (rows.isEmpty) {
        throw const ReservationException('Ce plat n’existe plus.');
      }

      final row = rows.first;
      final stock = (row['quantite'] as num).toInt();
      if (row['restaurant_statut'] != 'actif') {
        throw const ReservationException(
          'Ce restaurant n’accepte plus de réservations.',
        );
      }
      if (row['disponible'] != 1 || stock == 0) {
        throw const ReservationException('Ce plat n’est plus disponible.');
      }
      if (reservation.quantity > stock) {
        throw ReservationException(
          'Stock insuffisant : il ne reste que $stock portion(s).',
        );
      }

      // Dernière portion réservée → le plat passe automatiquement
      // « non disponible ».
      await txn.rawUpdate(
        'UPDATE menus SET quantite = quantite - ?, '
        'disponible = CASE WHEN quantite - ? <= 0 THEN 0 ELSE disponible END '
        'WHERE id = ?',
        [reservation.quantity, reservation.quantity, menuId],
      );
      final id = await txn.insert('reservations', reservation.toMap());
      return reservation.copyWith(id: id);
    });
  }

  Future<List<Reservation>> getAll({int? restaurantId}) async {
    final rows = await (await _database).query(
      'reservations',
      where: restaurantId == null ? null : 'restaurant_id = ?',
      whereArgs: restaurantId == null ? null : [restaurantId],
      orderBy: 'heure_retrait DESC',
    );
    return rows.map(Reservation.fromMap).toList();
  }

  Future<Reservation?> getById(int id) async {
    final rows = await (await _database).query(
      'reservations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Reservation.fromMap(rows.first);
  }

  /// Enregistre le résultat de l'analyse IA de la note client.
  Future<void> saveNoteAnalysis(int id, NoteAnalysis analysis) async {
    await (await _database).update(
      'reservations',
      {'analyse_note': analysis.encode()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> referenceExists(String reference) async {
    final rows = await (await _database).query(
      'reservations',
      columns: ['id'],
      where: 'reference = ?',
      whereArgs: [reference],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Met à jour le statut seulement si la réservation est toujours dans
  /// l'état attendu (évite d'écraser un changement fait entre-temps).
  Future<void> updateStatus(int id, String from, String to) async {
    final count = await (await _database).update(
      'reservations',
      {'statut': to},
      where: 'id = ? AND statut = ?',
      whereArgs: [id, from],
    );
    if (count == 0) {
      throw const ReservationException(
        'La réservation a changé entre-temps. Actualisez la page.',
      );
    }
  }

  /// Annule la réservation et remet les portions en stock.
  Future<void> cancelAndRestock(Reservation reservation) async {
    final id = reservation.id;
    if (id == null) {
      throw const ReservationException('Réservation introuvable.');
    }

    final database = await _database;
    await database.transaction((txn) async {
      final count = await txn.update(
        'reservations',
        {'statut': ReservationStatus.annulee},
        where: 'id = ? AND statut = ?',
        whereArgs: [id, reservation.status],
      );
      if (count == 0) {
        throw const ReservationException(
          'La réservation a changé entre-temps. Actualisez la page.',
        );
      }
      if (reservation.menuId != null) {
        // Si le plat était passé « non disponible » faute de stock, il
        // redevient disponible (sauf restaurant fermé / archivé).
        await txn.rawUpdate(
          '''
          UPDATE menus SET
            disponible = CASE
              WHEN quantite = 0 AND (
                SELECT statut FROM restaurants WHERE id = menus.restaurant_id
              ) = 'actif' THEN 1
              ELSE disponible END,
            quantite = quantite + ?
          WHERE id = ?
          ''',
          [reservation.quantity, reservation.menuId],
        );
      }
    });
  }
}
