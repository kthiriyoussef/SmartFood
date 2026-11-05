import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  static const int version = 2;

  static Future<void> create(Database database, int _) async {
    await database.execute('''
      CREATE TABLE restaurants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        adresse TEXT NOT NULL,
        ville TEXT NOT NULL,
        telephone TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'actif'
        CHECK (statut IN ('actif', 'archive')),
        date_creation TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE menus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        description TEXT,
        prix REAL NOT NULL CHECK (prix > 0),
        categorie TEXT NOT NULL,
        quantite INTEGER NOT NULL DEFAULT 0 CHECK (quantite >= 0),
        disponible INTEGER NOT NULL DEFAULT 1
          CHECK (disponible IN (0, 1)),
        date_creation TEXT NOT NULL,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurants(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_menus_restaurant_id ON menus(restaurant_id)',
    );
  }

  static Future<void> upgrade(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE menus ADD COLUMN quantite INTEGER NOT NULL DEFAULT 0 '
        'CHECK (quantite >= 0)',
      );
    }
  }
}
