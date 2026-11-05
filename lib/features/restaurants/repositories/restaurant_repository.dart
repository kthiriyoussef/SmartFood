import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';

class RestaurantRepository {
  Future<Database> get _database => DatabaseHelper.instance.database;

  Future<List<Restaurant>> getAllRestaurants() async {
    final rows = await (await _database).query(
      'restaurants',
      orderBy: 'nom COLLATE NOCASE',
    );
    return rows.map(Restaurant.fromMap).toList();
  }

  Future<Restaurant?> getRestaurantById(int id) async {
    final rows = await (await _database).query(
      'restaurants',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Restaurant.fromMap(rows.first);
  }

  Future<int> insertRestaurant(Restaurant restaurant) async {
    return (await _database).insert('restaurants', restaurant.toMap());
  }

  Future<void> updateRestaurant(Restaurant restaurant) async {
    final id = restaurant.id;
    if (id == null) {
      throw ArgumentError(
          'Un identifiant est requis pour modifier un restaurant.');
    }

    final count = await (await _database).update(
      'restaurants',
      restaurant.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Le restaurant $id n’existe pas.');
    }
  }

  /// Réservations non clôturées (en attente → prête) du restaurant.
  Future<int> countActiveReservations(int restaurantId) async {
    final result = await (await _database).rawQuery(
      '''
      SELECT COUNT(*) AS total FROM reservations
      WHERE restaurant_id = ?
        AND statut IN ('EN_ATTENTE', 'CONFIRMEE', 'PREPARATION', 'PRETE')
      ''',
      [restaurantId],
    );
    return (result.first['total'] as num).toInt();
  }

  /// Réactive le restaurant. Les plats restent indisponibles : le gérant
  /// les remet en vente un par un (stock à vérifier).
  Future<void> reactivateRestaurant(int id) async {
    final count = await (await _database).update(
      'restaurants',
      {'statut': RestaurantStatus.actif.name},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Le restaurant $id n’existe pas.');
    }
  }

  Future<void> archiveRestaurant(int id) async {
    final database = await _database;
    await database.transaction((transaction) async {
      final count = await transaction.update(
        'restaurants',
        {'statut': RestaurantStatus.archive.name},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw StateError('Le restaurant $id n’existe pas.');
      }
      await transaction.update(
        'menus',
        {'disponible': 0},
        where: 'restaurant_id = ?',
        whereArgs: [id],
      );
    });
  }
}
