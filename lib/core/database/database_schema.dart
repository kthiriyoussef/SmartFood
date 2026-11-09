import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  static const int version = 14;

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
        quantite INTEGER NOT NULL DEFAULT 0
          CHECK (quantite >= 0),
        disponible INTEGER NOT NULL DEFAULT 1
          CHECK (disponible IN (0, 1)),
        date_creation TEXT NOT NULL,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurants(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_menus_restaurant_id '
      'ON menus(restaurant_id)',
    );

    await _createReservations(database);
    await _createClientProfile(database);
    await _createSettings(database);
    await _createUsers(database);
    await _createSalesPurchases(database);
    await _createReclamations(database);
    await _createReclamationMessages(database);
    await _createRestaurantRoleRequests(database);
    await _createRestaurantAccessRequests(database);
  }

  static Future<void> upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE menus '
        'ADD COLUMN quantite INTEGER NOT NULL DEFAULT 0 '
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
    if (oldVersion < 6) {
      await _createUsers(database);
    }

    if (oldVersion < 7) {
      await _createReclamations(database);
    }

    // Migration de la version 7 vers la version 8.
    if (oldVersion == 7) {
      await _addColumnIfMissing(
        database,
        'reclamations',
        'reservation_ref',
        'TEXT',
      );

      await _addColumnIfMissing(
        database,
        'reclamations',
        'justificatif_name',
        'TEXT',
      );
    }

    // Migration vers la version 9 :
    // ajout de la priorité et de l'impact.
    if (oldVersion < 9) {
      await _addColumnIfMissing(
        database,
        'reclamations',
        'priorite',
        '''TEXT NOT NULL DEFAULT 'MOYENNE'
          CHECK (priorite IN (
            'FAIBLE',
            'MOYENNE',
            'ELEVEE',
            'URGENTE'
          ))''',
      );

      await _addColumnIfMissing(
        database,
        'reclamations',
        'impact',
        '''TEXT NOT NULL DEFAULT 'NORMAL'
          CHECK (impact IN ('NORMAL', 'FORT'))''',
      );

      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_reclamations_priorite '
        'ON reclamations(priorite)',
      );
    }
    // Migration vers la version 10 : messagerie des réclamations.
    if (oldVersion < 10) {
      await _createReclamationMessages(database);
    }
    // Migration version 11 : demandes de rôle RESTO.
    if (oldVersion < 11) {
      await _createRestaurantRoleRequests(database);
    }
    if (oldVersion < 12) {
      await _createRestaurantAccessRequests(database);
    }
    if (oldVersion < 13) {
      await _addColumnIfMissing(
        database,
        'reservations',
        'analyse_note',
        'TEXT',
      );
    }
    if (oldVersion < 14) {
      await _createSalesPurchases(database);
    }
  }

  static Future<void> _createSalesPurchases(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS fournisseurs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id INTEGER NOT NULL,
        date_vente TEXT NOT NULL,
        mode_paiement TEXT NOT NULL DEFAULT 'autre',
        montant_recu INTEGER NOT NULL DEFAULT 0,
        client_user_id INTEGER,
        sous_total INTEGER NOT NULL DEFAULT 0,
        remise INTEGER NOT NULL DEFAULT 0,
        taux_remise INTEGER NOT NULL DEFAULT 0,
        motif_annulation TEXT,
        statut TEXT NOT NULL DEFAULT 'en_attente',
        total INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(id),
        FOREIGN KEY (client_user_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS lignes_vente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL,
        designation TEXT NOT NULL,
        quantite REAL NOT NULL,
        prix_unitaire INTEGER NOT NULL,
        menu_id INTEGER,
        FOREIGN KEY (vente_id) REFERENCES ventes(id) ON DELETE CASCADE,
        FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE SET NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS achats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fournisseur_id INTEGER NOT NULL,
        restaurant_id INTEGER NOT NULL,
        date_achat TEXT NOT NULL,
        date_livraison_prevue TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'en_attente',
        total INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (fournisseur_id) REFERENCES fournisseurs(id),
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS lignes_achat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achat_id INTEGER NOT NULL,
        designation TEXT NOT NULL,
        quantite REAL NOT NULL,
        unite TEXT NOT NULL,
        prix_unitaire INTEGER NOT NULL,
        FOREIGN KEY (achat_id) REFERENCES achats(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_ventes_restaurant_date '
      'ON ventes(restaurant_id, date_vente)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_achats_restaurant_date '
      'ON achats(restaurant_id, date_achat)',
    );
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor database,
    String table,
    String column,
    String definition,
  ) async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (tables.isEmpty) return;

    final columns = await database.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;

    await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Réservations des clients.
  /// Les informations des plats et restaurants sont conservées
  /// même si le menu original est modifié.
  static Future<void> _createReservations(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL UNIQUE,
        menu_id INTEGER,
        restaurant_id INTEGER,
        restaurant_nom TEXT NOT NULL,
        menu_nom TEXT NOT NULL,
        prix_unitaire REAL NOT NULL
          CHECK (prix_unitaire > 0),
        quantite INTEGER NOT NULL
          CHECK (quantite > 0),
        client_prenom TEXT NOT NULL,
        client_nom TEXT NOT NULL,
        telephone TEXT NOT NULL,
        note TEXT,
        heure_retrait TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'EN_ATTENTE'
          CHECK (statut IN (
            'EN_ATTENTE',
            'CONFIRMEE',
            'PREPARATION',
            'PRETE',
            'RECUPEREE',
            'ANNULEE'
          )),
        code_pin TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        analyse_note TEXT,
        FOREIGN KEY (menu_id)
          REFERENCES menus(id)
          ON DELETE SET NULL,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurants(id)
          ON DELETE SET NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_reservations_statut '
      'ON reservations(statut)',
    );

    await database.execute(
      'CREATE INDEX idx_reservations_restaurant_id '
      'ON reservations(restaurant_id)',
    );
  }

  /// Profil local du client.
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

  /// Paramètres de l'application.
  static Future<void> _createSettings(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE app_settings (
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');
  }

  /// Comptes utilisateurs.
  static Future<void> _createUsers(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL
          CHECK (role IN (
            'ADMIN',
            'RESTO',
            'CLIENT'
          )),
        restaurant_id INTEGER,
        actif INTEGER NOT NULL DEFAULT 1
          CHECK (actif IN (0, 1)),
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurants(id)
          ON DELETE SET NULL
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_users_restaurant_id '
      'ON users(restaurant_id)',
    );
  }

  /// Réclamations clients avec priorité automatique.
  static Future<void> _createReclamations(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE reclamations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        sujet TEXT NOT NULL,
        description TEXT NOT NULL,
        reservation_ref TEXT,

        statut TEXT NOT NULL DEFAULT 'EN_ATTENTE'
          CHECK (statut IN (
            'EN_ATTENTE',
            'EN_COURS',
            'RESOLUE',
            'REJETEE'
          )),

        priorite TEXT NOT NULL DEFAULT 'MOYENNE'
          CHECK (priorite IN (
            'FAIBLE',
            'MOYENNE',
            'ELEVEE',
            'URGENTE'
          )),

        impact TEXT NOT NULL DEFAULT 'NORMAL'
          CHECK (impact IN (
            'NORMAL',
            'FORT'
          )),

        justificatif_path TEXT,
        justificatif_name TEXT,
        date_creation TEXT NOT NULL,
        date_modification TEXT,

        FOREIGN KEY (user_id)
          REFERENCES users(id)
          ON DELETE RESTRICT
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_reclamations_user_id '
      'ON reclamations(user_id)',
    );

    await database.execute(
      'CREATE INDEX idx_reclamations_statut '
      'ON reclamations(statut)',
    );

    await database.execute(
      'CREATE INDEX idx_reclamations_priorite '
      'ON reclamations(priorite)',
    );
  }

  static Future<void> _createReclamationMessages(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
    CREATE TABLE reclamation_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reclamation_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL,
      message TEXT NOT NULL
        CHECK (length(trim(message)) > 0),
      date_envoi TEXT NOT NULL,
      date_lecture TEXT,

      FOREIGN KEY (reclamation_id)
        REFERENCES reclamations(id)
        ON DELETE CASCADE,

      FOREIGN KEY (sender_id)
        REFERENCES users(id)
        ON DELETE RESTRICT
    )
  ''');

    await database.execute('''
    CREATE INDEX idx_reclamation_messages_ticket
    ON reclamation_messages(reclamation_id, date_envoi, id)
  ''');

    await database.execute('''
    CREATE INDEX idx_reclamation_messages_sender
    ON reclamation_messages(sender_id)
  ''');
  }

  static Future<void> _createRestaurantRoleRequests(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
    CREATE TABLE restaurant_role_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      restaurant_id INTEGER NOT NULL,
      statut TEXT NOT NULL DEFAULT 'EN_ATTENTE'
        CHECK (statut IN (
          'EN_ATTENTE',
          'ACCEPTEE',
          'REFUSEE'
        )),
      date_demande TEXT NOT NULL,
      date_decision TEXT,
      admin_id INTEGER,

      FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE RESTRICT,

      FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(id)
        ON DELETE RESTRICT,

      FOREIGN KEY (admin_id)
        REFERENCES users(id)
        ON DELETE SET NULL
    )
  ''');

    await database.execute('''
    CREATE INDEX idx_resto_requests_status
    ON restaurant_role_requests(statut)
  ''');

    await database.execute('''
    CREATE INDEX idx_resto_requests_user
    ON restaurant_role_requests(user_id)
  ''');

    await database.execute('''
    CREATE UNIQUE INDEX idx_resto_requests_one_pending
    ON restaurant_role_requests(user_id)
    WHERE statut = 'EN_ATTENTE'
  ''');
  }

  static Future<void> _createRestaurantAccessRequests(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
    CREATE TABLE restaurant_access_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      user_name TEXT NOT NULL,
      user_email TEXT NOT NULL,
      requested_role TEXT NOT NULL DEFAULT 'restaurant'
        CHECK (requested_role = 'restaurant'),
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
      submitted_at TEXT NOT NULL,
      reviewed_at TEXT,
      admin_id INTEGER,
      FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE RESTRICT,
      FOREIGN KEY (admin_id)
        REFERENCES users(id)
        ON DELETE SET NULL
    )
  ''');

    await database.execute(
      'CREATE INDEX idx_restaurant_access_requests_status '
      'ON restaurant_access_requests(status)',
    );
    await database.execute(
      'CREATE INDEX idx_restaurant_access_requests_user '
      'ON restaurant_access_requests(user_id, submitted_at)',
    );
    await database.execute('''
    CREATE UNIQUE INDEX idx_restaurant_access_one_pending
    ON restaurant_access_requests(user_id)
    WHERE status = 'pending'
  ''');
  }
}
