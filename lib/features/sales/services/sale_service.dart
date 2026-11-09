import '../models/sale.dart';

class SaleService {
  static void validate(Sale sale) {
    if (sale.restaurantId <= 0) {
      throw ArgumentError('Choisissez un restaurant.');
    }
    if (sale.lines.isEmpty) throw ArgumentError('Ajoutez au moins un article.');
    for (final line in sale.lines) {
      if (line.dishId == null || line.dishId! <= 0) {
        throw ArgumentError('Choisissez un plat du menu du restaurant.');
      }
      if (line.designation.trim().isEmpty) {
        throw ArgumentError('La désignation est obligatoire.');
      }
      if (line.quantity <= 0) {
        throw ArgumentError('La quantité doit être supérieure à zéro.');
      }
      if (!line.quantity.isFinite || line.quantity % 1 != 0) {
        throw ArgumentError('La quantité vendue doit être un nombre entier.');
      }
      if (line.unitPrice < 0) {
        throw ArgumentError('Le prix ne peut pas être négatif.');
      }
    }
    if (sale.date.isBefore(DateTime(2000))) {
      throw ArgumentError('La date de vente est invalide.');
    }
  }

  static int changePayment({
    required int total,
    required String mode,
    required int received,
  }) {
    if (mode == 'especes' && received < total) {
      throw ArgumentError('Le montant reçu est inférieur au total.');
    }
    if (mode != 'especes' && received != total) {
      throw ArgumentError('Le montant reçu doit correspondre au total.');
    }
    return mode == 'especes' ? received - total : 0;
  }

  static void ensureEditable(String status) {
    if (status != 'en_attente') {
      throw StateError('Seule une vente en attente peut être modifiée.');
    }
  }
}
