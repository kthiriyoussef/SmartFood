import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartfood/core/database/database_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.close();
  });

  test('upgrade from version 6 tolerates current reclamation columns',
      () async {
    await database.execute('CREATE TABLE users (id INTEGER PRIMARY KEY)');

    await DatabaseSchema.upgrade(database, 6, DatabaseSchema.version);

    final columns = await database.rawQuery(
      'PRAGMA table_info(reclamations)',
    );
    final columnNames = columns.map((row) => row['name']).toSet();

    expect(columnNames, containsAll(['priorite', 'impact']));
    expect(
      await database.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name = 'reclamation_messages'",
      ),
      isNotEmpty,
    );
  });

  test('upgrade from version 8 adds missing reclamation columns', () async {
    await database.execute('CREATE TABLE users (id INTEGER PRIMARY KEY)');
    await database.execute('''
      CREATE TABLE reclamations (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        reservation_ref TEXT,
        justificatif_name TEXT
      )
    ''');

    await DatabaseSchema.upgrade(database, 8, DatabaseSchema.version);

    await database.insert('reclamations', {'user_id': 1});
    final row = (await database.query('reclamations')).single;
    expect(row['priorite'], 'MOYENNE');
    expect(row['impact'], 'NORMAL');
  });
}
