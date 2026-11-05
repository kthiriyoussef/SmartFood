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

  Future<int> sauvegarderMenu(Menu menu) async {
    _valider(menu);
    if (menu.id == null) return _repository.insertMenu(menu);
    await _repository.updateMenu(menu);
    return menu.id!;
  }

  Future<void> supprimerMenu(int id) => _repository.deleteMenu(id);

  Future<void> modifierDisponibilite(int id, bool disponible) =>
      _repository.toggleDisponibilite(id, disponible);

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
      throw const MenuValidationException('Le prix doit être supérieur à zéro.');
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
