import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/core/database/database_seeder.dart';

/// Restaurant géré par l'espace restaurant. Sans authentification, c'est le
/// « Restaurant Test » créé automatiquement (id mémorisé dans app_settings).
class CurrentRestaurant {
  CurrentRestaurant._();

  static Future<int> id() async {
    final database = await DatabaseHelper.instance.database;
    final rows = await database.query(
      'app_settings',
      where: 'cle = ?',
      whereArgs: [DatabaseSeeder.currentRestaurantKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      await DatabaseSeeder.ensureTestRestaurant(database);
      return id();
    }
    return int.parse(rows.first['valeur'] as String);
  }
}
