import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/repositories/restaurant_repository.dart';

class RestaurantValidationException implements Exception {
  const RestaurantValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum RestaurantPostLoginDestination {
  existingRoleFlow,
  createRestaurant,
  restaurantDashboard,
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

  Future<RestaurantPostLoginDestination> getPostLoginDestination({
    required int userId,
    required String role,
  }) async {
    final normalizedRole = role.trim().toUpperCase();
    if (normalizedRole != 'RESTO' && normalizedRole != 'RESTAURANT') {
      return RestaurantPostLoginDestination.existingRoleFlow;
    }

    final restaurantId = await _repository.getRestaurantIdForOwner(userId);
    return restaurantId == null
        ? RestaurantPostLoginDestination.createRestaurant
        : RestaurantPostLoginDestination.restaurantDashboard;
  }

  Future<int> sauvegarderRestaurant(Restaurant restaurant) async {
    final cleaned = restaurant.copyWith(
      nom: restaurant.nom.trim(),
      adresse: restaurant.adresse.trim(),
      ville: restaurant.ville.trim(),
      telephone: restaurant.telephone.trim(),
    );
    _valider(cleaned);
    final id = cleaned.id == null
        ? await _repository.insertRestaurant(cleaned)
        : await _updateAndReturnId(cleaned);
    DataChanges.catalogChanged();
    return id;
  }

  Future<int> sauvegarderRestaurantPourProprietaire(
    Restaurant restaurant,
    int userId,
  ) async {
    final cleaned = restaurant.copyWith(
      nom: restaurant.nom.trim(),
      adresse: restaurant.adresse.trim(),
      ville: restaurant.ville.trim(),
      telephone: restaurant.telephone.trim(),
    );
    _valider(cleaned);

    try {
      final id = await _repository.createRestaurantForOwner(cleaned, userId);
      DataChanges.catalogChanged();
      return id;
    } on RestaurantOwnershipException catch (error) {
      throw RestaurantValidationException(error.message);
    }
  }

  Future<int> _updateAndReturnId(Restaurant restaurant) async {
    await _repository.updateRestaurant(restaurant);
    return restaurant.id!;
  }

  /// Archive le restaurant et rend tous ses plats indisponibles.
  /// Refusé tant que des réservations sont en cours : le gérant doit
  /// d'abord les traiter ou les refuser.
  Future<void> archiverRestaurant(int id) async {
    final active = await _repository.countActiveReservations(id);
    if (active > 0) {
      throw RestaurantValidationException(
        'Impossible d’archiver : $active réservation(s) en cours. '
        'Traitez-les ou refusez-les d’abord.',
      );
    }
    await _repository.archiveRestaurant(id);
    DataChanges.catalogChanged();
  }

  Future<void> reactiverRestaurant(int id) async {
    await _repository.reactivateRestaurant(id);
    DataChanges.catalogChanged();
  }

  Future<int> compterReservationsActives(int id) =>
      _repository.countActiveReservations(id);

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
      throw const RestaurantValidationException(
          'Le téléphone est obligatoire.');
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
