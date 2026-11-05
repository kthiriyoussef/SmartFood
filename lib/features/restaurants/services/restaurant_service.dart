import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/repositories/restaurant_repository.dart';

class RestaurantValidationException implements Exception {
  const RestaurantValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RestaurantService {
  RestaurantService({RestaurantRepository? repository})
    : _repository = repository ?? RestaurantRepository();

  final RestaurantRepository _repository;

  Future<List<Restaurant>> getRestaurants({
    bool inclureArchives = false,
  }) async {
    final restaurants = await _repository.getAllRestaurants();
    if (inclureArchives) return restaurants;
    return restaurants
        .where((restaurant) => restaurant.statut == RestaurantStatus.actif)
        .toList();
  }

  Future<Restaurant?> getRestaurantById(int id) =>
      _repository.getRestaurantById(id);

  Future<int> sauvegarderRestaurant(Restaurant restaurant) async {
    _valider(restaurant);
    if (restaurant.id == null) {
      return _repository.insertRestaurant(restaurant);
    }
    await _repository.updateRestaurant(restaurant);
    return restaurant.id!;
  }

  Future<void> archiverRestaurant(int id) =>
      _repository.archiveRestaurant(id);

  List<Restaurant> rechercherRestaurants(
    List<Restaurant> restaurants,
    String recherche,
  ) {
    final needle = recherche.trim().toLowerCase();
    if (needle.isEmpty) return restaurants;
    return restaurants.where((restaurant) {
      return restaurant.nom.toLowerCase().contains(needle) ||
          restaurant.adresse.toLowerCase().contains(needle) ||
          restaurant.ville.toLowerCase().contains(needle) ||
          restaurant.telephone.toLowerCase().contains(needle);
    }).toList();
  }

  void _valider(Restaurant restaurant) {
    if (restaurant.nom.trim().isEmpty) {
      throw const RestaurantValidationException('Le nom est obligatoire.');
    }
    if (restaurant.adresse.trim().isEmpty) {
      throw const RestaurantValidationException('L’adresse est obligatoire.');
    }
    if (restaurant.ville.trim().isEmpty) {
      throw const RestaurantValidationException('La ville est obligatoire.');
    }
    if (restaurant.telephone.trim().isEmpty) {
      throw const RestaurantValidationException('Le téléphone est obligatoire.');
    }

    final telephone = restaurant.telephone.trim();
    final digits = telephone.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9().\s-]+$').hasMatch(telephone) ||
        digits.length < 7 ||
        digits.length > 15) {
      throw const RestaurantValidationException(
        'Saisissez un numéro valide (7 à 15 chiffres).',
      );
    }
  }
}
