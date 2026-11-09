import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository({Database? testDatabase}) : _testDatabase = testDatabase;

  final Database? _testDatabase;

  Future<Database> get _database async =>
      _testDatabase ?? await DatabaseHelper.instance.database;

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

  Future<int?> getRestaurantIdForOwner(int userId) async {
    final database = await _database;
    final users = await database.query(
      'users',
      columns: ['role', 'restaurant_id'],
      where: 'id = ? AND actif = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (users.isEmpty ||
        !const ['RESTO', 'RESTAURANT'].contains(users.single['role'])) {
      throw StateError('Compte restaurant actif introuvable.');
    }

    final restaurantId = users.single['restaurant_id'] as int?;
    if (restaurantId == null) return null;

    final restaurants = await database.query(
      'restaurants',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [restaurantId],
      limit: 1,
    );
    if (restaurants.isEmpty) {
      throw StateError('Le restaurant associé au compte est introuvable.');
    }
    return restaurantId;
  }

  Future<int> createRestaurantForOwner(
    Restaurant restaurant,
    int userId,
  ) async {
    final database = await _database;
    return database.transaction((transaction) async {
      final users = await transaction.query(
        'users',
        columns: ['role', 'restaurant_id'],
        where: 'id = ? AND actif = 1',
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty ||
          !const ['RESTO', 'RESTAURANT'].contains(users.single['role'])) {
        throw const RestaurantOwnershipException(
          'Un compte restaurant actif est requis.',
        );
      }
      if (users.single['restaurant_id'] != null) {
        throw const RestaurantOwnershipException(
          'Ce compte possède déjà un restaurant associé.',
        );
      }

      final restaurantId = await transaction.insert(
        'restaurants',
        restaurant.toMap(),
      );
      final updated = await transaction.update(
        'users',
        {'restaurant_id': restaurantId},
        where: "id = ? AND role IN ('RESTO', 'RESTAURANT') AND actif = 1 "
            'AND restaurant_id IS NULL',
        whereArgs: [userId],
      );
      if (updated != 1) {
        throw const RestaurantOwnershipException(
          'Impossible d’associer le restaurant à ce compte.',
        );
      }
      return restaurantId;
    });
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

class RestaurantOwnershipException implements Exception {
  const RestaurantOwnershipException(this.message);

  final String message;

  @override
  String toString() => message;
}
