class Menu {
  const Menu({
    this.id,
    required this.restaurantId,
    required this.nom,
    this.description,
    required this.prix,
    required this.categorie,
    this.quantite = 0,
    this.disponible = true,
    required this.dateCreation,
  });

  final int? id;
  final int restaurantId;
  final String nom;
  final String? description;
  final double prix;
  final String categorie;
  final int quantite;
  final bool disponible;
  final DateTime dateCreation;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'restaurant_id': restaurantId,
    'nom': nom,
    'description': description,
    'prix': prix,
    'categorie': categorie,
    'quantite': quantite,
    'disponible': disponible ? 1 : 0,
    'date_creation': dateCreation.toIso8601String(),
  };

  factory Menu.fromMap(Map<String, Object?> map) {
    final availability = map['disponible'] as int;
    if (availability != 0 && availability != 1) {
      throw FormatException('Valeur de disponibilité invalide : $availability');
    }

    return Menu(
      id: map['id'] as int,
      restaurantId: map['restaurant_id'] as int,
      nom: map['nom'] as String,
      description: map['description'] as String?,
      prix: (map['prix'] as num).toDouble(),
      categorie: map['categorie'] as String,
      quantite: (map['quantite'] as num?)?.toInt() ?? 0,
      disponible: availability == 1,
      dateCreation: DateTime.parse(map['date_creation'] as String),
    );
  }

  Menu copyWith({
    int? id,
    int? restaurantId,
    String? nom,
    String? description,
    bool clearDescription = false,
    double? prix,
    String? categorie,
    int? quantite,
    bool? disponible,
    DateTime? dateCreation,
  }) {
    return Menu(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      nom: nom ?? this.nom,
      description: clearDescription ? null : description ?? this.description,
      prix: prix ?? this.prix,
      categorie: categorie ?? this.categorie,
      quantite: quantite ?? this.quantite,
      disponible: disponible ?? this.disponible,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}
