import 'package:sqflite/sqflite.dart';

/// Données de démonstration insérées quand la base ne contient aucun
/// restaurant (premier lancement). Reprend les exemples des écrans clients.
class DatabaseSeeder {
  DatabaseSeeder._();

  static Future<void> seedIfEmpty(Database database) async {
    final count = Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM restaurants'),
        ) ??
        0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();

    await database.transaction((txn) async {
      for (final restaurant in _restaurants) {
        final restaurantId = await txn.insert('restaurants', {
          'nom': restaurant.nom,
          'adresse': restaurant.adresse,
          'ville': restaurant.ville,
          'telephone': restaurant.telephone,
          'statut': 'actif',
          'date_creation': now,
        });

        for (final menu in restaurant.menus) {
          await txn.insert('menus', {
            'restaurant_id': restaurantId,
            'nom': menu.nom,
            'description': menu.description,
            'prix': menu.prix,
            'categorie': menu.categorie,
            'quantite': menu.quantite,
            'disponible': menu.disponible ? 1 : 0,
            'date_creation': now,
          });
        }
      }
    });
  }

  /// Clé (table app_settings) de l'id du restaurant géré par l'espace
  /// restaurant.
  static const String currentRestaurantKey = 'restaurant_courant_id';

  /// Crée le restaurant de test (et sa carte) s'il n'existe pas encore,
  /// et mémorise son id. Idempotent : appelé à chaque ouverture de la base.
  static Future<void> ensureTestRestaurant(Database database) async {
    final rows = await database.query(
      'app_settings',
      where: 'cle = ?',
      whereArgs: [currentRestaurantKey],
    );
    if (rows.isNotEmpty) {
      final id = int.tryParse(rows.first['valeur'] as String);
      final exists = id != null &&
          (await database.query('restaurants',
                  where: 'id = ?', whereArgs: [id], limit: 1))
              .isNotEmpty;
      if (exists) return;
    }

    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      final id = await txn.insert('restaurants', {
        'nom': _testRestaurant.nom,
        'adresse': _testRestaurant.adresse,
        'ville': _testRestaurant.ville,
        'telephone': _testRestaurant.telephone,
        'statut': 'actif',
        'date_creation': now,
      });
      for (final menu in _testRestaurant.menus) {
        await txn.insert('menus', {
          'restaurant_id': id,
          'nom': menu.nom,
          'description': menu.description,
          'prix': menu.prix,
          'categorie': menu.categorie,
          'quantite': menu.quantite,
          'disponible': menu.disponible ? 1 : 0,
          'date_creation': now,
        });
      }
      await txn.insert(
        'app_settings',
        {'cle': currentRestaurantKey, 'valeur': '$id'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static const _SeedRestaurant _testRestaurant = _SeedRestaurant(
    nom: 'Restaurant Test',
    adresse: 'Avenue Habib Bourguiba',
    ville: 'Tunis',
    telephone: '+216 71 000 000',
    menus: [
      _SeedMenu('Salade tunisienne',
          'Tomates, concombre, oignon, thon et olives.', 8, 'Entrée', 15),
      _SeedMenu('Lablabi', 'Pois chiches, pain, harissa, œuf et cumin.', 7,
          'Plat', 12),
      _SeedMenu('Escalope panée', 'Escalope de poulet, frites et salade.', 19,
          'Plat', 3),
      _SeedMenu('Makroudh', 'Semoule, dattes et miel.', 5, 'Dessert', 20),
      _SeedMenu('Jus d’orange', 'Oranges pressées minute.', 6, 'Boisson', 0,
          disponible: false),
    ],
  );

  static const List<_SeedRestaurant> _restaurants = [
    _SeedRestaurant(
      nom: 'Le Jardin Gourmand',
      adresse: 'Les Berges du Lac',
      ville: 'Tunis',
      telephone: '+216 71 123 456',
      menus: [
        _SeedMenu(
            'Brik à l’œuf',
            'Thon, câpres et œuf frais dans une feuille croustillante.',
            8.5,
            'Entrée',
            14),
        _SeedMenu('Couscous du chef',
            'Légumes de saison et agneau mijoté aux épices.', 26, 'Plat', 8),
        _SeedMenu('Bowl méditerranéen',
            'Céréales, légumes frais et sauce aux herbes.', 18, 'Plat', 6),
        _SeedMenu('Pâtisseries maison',
            'Sélection du jour, préparée sur place.', 12, 'Dessert', 0,
            disponible: false),
        _SeedMenu('Citronnade à la menthe',
            'Citron fraîchement pressé et menthe.', 6, 'Boisson', 20),
      ],
    ),
    _SeedRestaurant(
      nom: 'Café des Oliviers',
      adresse: 'Centre-ville',
      ville: 'Sousse',
      telephone: '+216 73 456 789',
      menus: [
        _SeedMenu(
            'Salade méchouia',
            'Poivrons et tomates grillés, thon, œuf et huile d’olive.',
            9,
            'Entrée',
            10),
        _SeedMenu('Ojja merguez',
            'Sauce tomate épicée, merguez et œufs pochés.', 16, 'Plat', 4),
        _SeedMenu('Poisson grillé',
            'Daurade du jour, légumes vapeur et citron.', 32, 'Plat', 5),
        _SeedMenu('Thé aux pignons', 'Thé vert à la menthe et pignons grillés.',
            5, 'Boisson', 30),
      ],
    ),
    _SeedRestaurant(
      nom: 'La Table du Marché',
      adresse: 'El Menzah 6',
      ville: 'Tunis',
      telephone: '+216 71 987 654',
      menus: [
        _SeedMenu('Soupe de lentilles', 'Lentilles corail, cumin et citron.', 7,
            'Entrée', 12),
        _SeedMenu(
            'Menu du marché',
            'Entrée, plat et dessert selon l’arrivage du jour.',
            35,
            'Menu complet',
            3),
        _SeedMenu('Assida aux pignons', 'Crème parfumée, pignons et pistaches.',
            11, 'Dessert', 7),
      ],
    ),
  ];
}

class _SeedRestaurant {
  const _SeedRestaurant({
    required this.nom,
    required this.adresse,
    required this.ville,
    required this.telephone,
    required this.menus,
  });

  final String nom;
  final String adresse;
  final String ville;
  final String telephone;
  final List<_SeedMenu> menus;
}

class _SeedMenu {
  const _SeedMenu(
    this.nom,
    this.description,
    this.prix,
    this.categorie,
    this.quantite, {
    this.disponible = true,
  });

  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final int quantite;
  final bool disponible;
}
