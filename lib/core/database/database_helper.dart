import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_schema.dart';
import 'package:smartfood/core/database/database_seeder.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final current = _databaseFuture;
    if (current != null) return current;
    final opening = _openDatabase();
    _databaseFuture = opening;
    return opening.catchError((Object error) {
      if (identical(_databaseFuture, opening)) _databaseFuture = null;
      throw error;
    });
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    return openDatabase(
      path.join(databasePath, 'smartfood.db'),
      version: DatabaseSchema.version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: DatabaseSchema.create,
      onUpgrade: DatabaseSchema.upgrade,
      onOpen: (database) async {
        await DatabaseSeeder.seedIfEmpty(database);
        await DatabaseSeeder.ensureTestRestaurant(database);
        await DatabaseSeeder.ensureTestAdmin(database);
        await DatabaseSeeder.ensureSalesSuppliers(database);
      },
    );
  }

  Future<void> close() async {
    final current = _databaseFuture;
    if (current == null) return;

    await (await current).close();
    if (identical(_databaseFuture, current)) _databaseFuture = null;
  }
}
