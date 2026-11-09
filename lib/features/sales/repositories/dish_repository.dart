import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/dish.dart';

/// Read-only adapter over the restaurant's existing `menus` catalog.
class DishRepository {
  DishRepository({this.database});
  final Database? database;
  Future<Database> get _db async {
    final injected = database;
    return injected ?? await DatabaseHelper.instance.database;
  }

  Future<List<Dish>> forRestaurant(
    int restaurantId, {
    bool availableOnly = true,
  }) async {
    final rows = await (await _db).query(
      'menus',
      where: availableOnly
          ? 'restaurant_id = ? AND disponible = 1 AND quantite > 0'
          : 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'nom COLLATE NOCASE',
    );
    return rows.map(Dish.fromMap).toList();
  }

  Future<List<Dish>> all() async => (await (await _db).query(
    'menus',
    where: 'disponible = 1 AND quantite > 0',
    orderBy: 'restaurant_id, nom COLLATE NOCASE',
  )).map(Dish.fromMap).toList();
}
