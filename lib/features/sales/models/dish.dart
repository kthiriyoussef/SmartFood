class Dish {
  const Dish({
    this.id,
    required this.restaurantId,
    required this.name,
    this.description = '',
    required this.price,
    this.available = true,
  });
  final int? id;
  final int restaurantId;
  final String name;
  final String description;
  final int price;
  final bool available;

  factory Dish.fromMap(Map<String, Object?> map) => Dish(
    id: map['id'] as int,
    restaurantId: map['restaurant_id'] as int,
    name: map['nom'] as String,
    description: map['description'] as String? ?? '',
    price: ((map['prix'] as num) * 1000).round(),
    available:
        (map['disponible'] as int? ?? 1) == 1 &&
        ((map['quantite'] as num?)?.toInt() ?? 0) > 0,
  );

  Map<String, Object?> toMap() => {
    'restaurant_id': restaurantId,
    'nom': name.trim(),
    'description': description.trim(),
    'prix': price,
    'disponible': available ? 1 : 0,
  };
}
