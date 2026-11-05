import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';

class MenuRepository {
  Future<Database> get _database => DatabaseHelper.instance.database;

  Future<List<Menu>> getMenusByRestaurant(int restaurantId) async {
    final rows = await (await _database).query(
      'menus',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'categorie COLLATE NOCASE, nom COLLATE NOCASE',
    );
    return rows.map(Menu.fromMap).toList();
  }

  Future<int> insertMenu(Menu menu) async {
    return (await _database).insert('menus', menu.toMap());
  }

  Future<void> updateMenu(Menu menu) async {
    final id = menu.id;
    if (id == null) {
      throw ArgumentError('Un identifiant est requis pour modifier un menu.');
    }

    final count = await (await _database).update(
      'menus',
      menu.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Le menu $id n’existe pas.');
    }
  }

  Future<void> deleteMenu(int id) async {
    final count = await (await _database).delete(
      'menus',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Le menu $id n’existe pas.');
    }
  }

  Future<void> toggleDisponibilite(int id, bool disponible) async {
    final count = await (await _database).update(
      'menus',
      {'disponible': disponible ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Le menu $id n’existe pas.');
    }
  }
}
