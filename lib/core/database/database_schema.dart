import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  static const int version = 5;

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

    await _createReservations(database);
    await _createClientProfile(database);
    await _createSettings(database);
  }

  static Future<void> upgrade(
      Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE menus ADD COLUMN quantite INTEGER NOT NULL DEFAULT 0 '
        'CHECK (quantite >= 0)',
      );
    }
    if (oldVersion < 3) {
      await _createReservations(database);
    }
    if (oldVersion < 4) {
      await _createClientProfile(database);
    }
    if (oldVersion < 5) {
      await _createSettings(database);
    }
  }

  /// Le nom du plat, du restaurant et le prix sont copiés dans la réservation :
  /// si le menu est modifié ou supprimé, l'historique reste exact
  /// (menu_id / restaurant_id passent alors à NULL).
  static Future<void> _createReservations(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL UNIQUE,
        menu_id INTEGER,
        restaurant_id INTEGER,
        restaurant_nom TEXT NOT NULL,
        menu_nom TEXT NOT NULL,
        prix_unitaire REAL NOT NULL CHECK (prix_unitaire > 0),
        quantite INTEGER NOT NULL CHECK (quantite > 0),
        client_prenom TEXT NOT NULL,
        client_nom TEXT NOT NULL,
        telephone TEXT NOT NULL,
        note TEXT,
        heure_retrait TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'EN_ATTENTE'
          CHECK (statut IN ('EN_ATTENTE', 'CONFIRMEE', 'PREPARATION',
                            'PRETE', 'RECUPEREE', 'ANNULEE')),
        code_pin TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE SET NULL,
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE SET NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_reservations_statut ON reservations(statut)',
    );
    await database.execute(
      'CREATE INDEX idx_reservations_restaurant_id ON reservations(restaurant_id)',
    );
  }

  /// Profil du client de l'appareil (une seule ligne, id = 1).
  static Future<void> _createClientProfile(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE profil_client (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        prenom TEXT NOT NULL,
        nom TEXT NOT NULL,
        indicatif TEXT NOT NULL,
        telephone TEXT NOT NULL
      )
    ''');
  }

  /// Réglages de l'application (clé / valeur), ex. le restaurant géré
  /// par l'espace restaurant.
  static Future<void> _createSettings(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE app_settings (
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');
  }
}
