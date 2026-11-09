import '../models/purchase.dart';

class PurchaseService {
  static void validate(Purchase purchase) {
    if (purchase.supplierId <= 0 || purchase.restaurantId <= 0) {
      throw ArgumentError('Choisissez un fournisseur et un restaurant.');
    }
    if (purchase.lines.isEmpty) {
      throw ArgumentError('Ajoutez au moins un produit.');
    }
    for (final line in purchase.lines) {
      if (line.designation.trim().isEmpty || line.unit.trim().isEmpty) {
        throw ArgumentError('Le produit et son unité sont obligatoires.');
      }
      if (line.quantity <= 0) {
        throw ArgumentError('La quantité doit être supérieure à zéro.');
      }
      if (line.unitPrice < 0) {
        throw ArgumentError('Le prix ne peut pas être négatif.');
      }
    }
    if (purchase.expectedDate.isBefore(DateTime(2000))) {
      throw ArgumentError('La date de livraison est invalide.');
    }
  }

  static void ensureReceivable(String status) {
    if (status != 'en_attente') {
      throw StateError('Cet achat n’est plus modifiable.');
    }
  }
}
