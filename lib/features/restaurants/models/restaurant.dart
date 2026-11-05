enum RestaurantStatus { actif, archive }

class Restaurant {
  const Restaurant({
    this.id,
    required this.nom,
    required this.adresse,
    required this.ville,
    required this.telephone,
    this.statut = RestaurantStatus.actif,
    required this.dateCreation,
  });

  final int? id;
  final String nom;
  final String adresse;
  final String ville;
  final String telephone;
  final RestaurantStatus statut;
  final DateTime dateCreation;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'nom': nom,
    'adresse': adresse,
    'ville': ville,
    'telephone': telephone,
    'statut': statut.name,
    'date_creation': dateCreation.toIso8601String(),
  };

  factory Restaurant.fromMap(Map<String, Object?> map) {
    final statusName = map['statut'] as String;
    return Restaurant(
      id: map['id'] as int,
      nom: map['nom'] as String,
      adresse: map['adresse'] as String,
      ville: map['ville'] as String,
      telephone: map['telephone'] as String,
      statut: RestaurantStatus.values.byName(statusName),
      dateCreation: DateTime.parse(map['date_creation'] as String),
    );
  }

  Restaurant copyWith({
    int? id,
    String? nom,
    String? adresse,
    String? ville,
    String? telephone,
    RestaurantStatus? statut,
    DateTime? dateCreation,
  }) {
    return Restaurant(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      adresse: adresse ?? this.adresse,
      ville: ville ?? this.ville,
      telephone: telephone ?? this.telephone,
      statut: statut ?? this.statut,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}
