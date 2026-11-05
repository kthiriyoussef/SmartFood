import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/repositories/menu_repository.dart';

class MenuValidationException implements Exception {
  const MenuValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MenuService {
  MenuService({MenuRepository? repository})
      : _repository = repository ?? MenuRepository();

  static const List<String> categories = [
    'Entrée',
    'Plat',
    'Dessert',
    'Boisson',
    'Menu complet',
  ];

  final MenuRepository _repository;

  Future<List<Menu>> getMenusByRestaurant(int restaurantId) =>
      _repository.getMenusByRestaurant(restaurantId);

  Future<List<Menu>> getAllMenus() => _repository.getAllMenus();

  /// Seuil sous lequel le stock est signalé comme bas.
  static const int seuilStockBas = 5;

  Future<int> sauvegarderMenu(Menu menu) async {
    final cleanDescription = menu.description?.trim();
    final cleaned = menu.copyWith(
      nom: menu.nom.trim(),
      description: cleanDescription,
      clearDescription: cleanDescription == null || cleanDescription.isEmpty,
      // Règle : sans stock, un plat n'est jamais disponible.
      disponible: menu.disponible && menu.quantite > 0,
    );
    _valider(cleaned);
    final int id;
    if (cleaned.id == null) {
      id = await _repository.insertMenu(cleaned);
    } else {
      await _repository.updateMenu(cleaned);
      id = cleaned.id!;
    }
    DataChanges.catalogChanged();
    return id;
  }

  /// Suppression refusée si des clients attendent ce plat : il vaut mieux
  /// le rendre indisponible (il disparaît des réservations possibles).
  Future<void> supprimerMenu(int id) async {
    final active = await _repository.countActiveReservations(id);
    if (active > 0) {
      throw MenuValidationException(
        'Ce plat a $active réservation(s) en cours. '
        'Rendez-le indisponible plutôt que de le supprimer.',
      );
    }
    await _repository.deleteMenu(id);
    DataChanges.catalogChanged();
  }

  Future<void> modifierDisponibilite(int id, bool disponible) async {
    if (disponible) {
      final menu = await _repository.getMenuById(id);
      if (menu == null) {
        throw const MenuValidationException('Plat introuvable.');
      }
      if (menu.quantite == 0) {
        throw const MenuValidationException(
          'Stock à 0 : ajoutez des portions pour remettre le plat en vente.',
        );
      }
    }
    await _repository.toggleDisponibilite(id, disponible);
    DataChanges.catalogChanged();
  }

  Future<void> ajusterStock(
    int id,
    int delta, {
    bool remettreEnVente = false,
  }) async {
    try {
      await _repository.adjustStock(
        id,
        delta,
        remettreEnVente: remettreEnVente,
      );
    } on StateError {
      throw const MenuValidationException('Le stock ne peut pas être négatif.');
    }
    DataChanges.catalogChanged();
  }

  List<Menu> filtrerParCategorie(List<Menu> menus, String categorie) {
    if (categorie == 'Toutes') return menus;
    return menus.where((menu) => menu.categorie == categorie).toList();
  }

  List<Menu> filtrerDisponibles(List<Menu> menus) =>
      menus.where((menu) => menu.disponible).toList();

  void _valider(Menu menu) {
    if (menu.nom.trim().isEmpty) {
      throw const MenuValidationException('Le nom du menu est obligatoire.');
    }
    if (!menu.prix.isFinite || menu.prix <= 0) {
      throw const MenuValidationException(
          'Le prix doit être supérieur à zéro.');
    }
    if (menu.quantite < 0) {
      throw const MenuValidationException(
        'La quantité en stock ne peut pas être négative.',
      );
    }
    if (menu.categorie.trim().isEmpty) {
      throw const MenuValidationException('Choisissez une catégorie.');
    }
  }
}
