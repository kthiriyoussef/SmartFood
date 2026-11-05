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

  Future<List<Menu>> getAllMenus() async {
    final rows = await (await _database).query(
      'menus',
      orderBy: 'nom COLLATE NOCASE',
    );
    return rows.map(Menu.fromMap).toList();
  }

  Future<Menu?> getMenuById(int id) async {
    final rows = await (await _database).query(
      'menus',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Menu.fromMap(rows.first);
  }

  /// Ajoute (delta > 0) ou retire (delta < 0) des portions, sans jamais
  /// descendre sous zéro. À 0, le plat devient non disponible ; avec
  /// [remettreEnVente], il redevient disponible s'il reste du stock.
  Future<void> adjustStock(
    int id,
    int delta, {
    bool remettreEnVente = false,
  }) async {
    final count = await (await _database).rawUpdate(
      'UPDATE menus SET quantite = quantite + ?, '
      'disponible = CASE '
      '  WHEN quantite + ? <= 0 THEN 0 '
      '  WHEN ? = 1 THEN 1 '
      '  ELSE disponible END '
      'WHERE id = ? AND quantite + ? >= 0',
      [delta, delta, remettreEnVente ? 1 : 0, id, delta],
    );
    if (count == 0) {
      throw StateError('Stock insuffisant ou plat introuvable.');
    }
  }

  Future<int> countActiveReservations(int menuId) async {
    final result = await (await _database).rawQuery(
      '''
      SELECT COUNT(*) AS total FROM reservations
      WHERE menu_id = ?
        AND statut IN ('EN_ATTENTE', 'CONFIRMEE', 'PREPARATION', 'PRETE')
      ''',
      [menuId],
    );
    return (result.first['total'] as num).toInt();
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
