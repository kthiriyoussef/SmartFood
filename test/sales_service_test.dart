import 'package:flutter_test/flutter_test.dart';
import 'package:smartfood/features/sales/models/sale.dart';
import 'package:smartfood/features/sales/services/sale_service.dart';
import 'package:smartfood/features/purchases/models/purchase.dart';
import 'package:smartfood/features/purchases/services/purchase_service.dart';

void main() {
  group('Règles de vente', () {
    test('calcule les montants en millimes et refuse une ligne invalide', () {
      final sale = Sale(
        restaurantId: 1,
        date: DateTime(2026, 10, 17),
        lines: [
          SaleLine(
            designation: 'Plat',
            quantity: 2,
            unitPrice: 1250,
            dishId: 1,
          ),
          SaleLine(designation: 'Jus', quantity: 1, unitPrice: 800, dishId: 2),
        ],
      );
      expect(sale.total, 3300);
      expect(
        () => SaleService.validate(
          Sale(restaurantId: 1, date: DateTime(2026), lines: []),
        ),
        throwsArgumentError,
      );
    });
    test(
      'paiement espèces calcule la monnaie et refuse montant insuffisant',
      () {
        expect(
          SaleService.changePayment(
            total: 1250,
            mode: 'especes',
            received: 2000,
          ),
          750,
        );
        expect(
          () => SaleService.changePayment(
            total: 1250,
            mode: 'especes',
            received: 1000,
          ),
          throwsArgumentError,
        );
      },
    );
    test('seule une vente en attente est modifiable', () {
      expect(() => SaleService.ensureEditable('payee'), throwsStateError);
    });
    test('refuse les quantités nulles, les prix négatifs et les désignations vides', () {
      Sale invalidSale(SaleLine line) =>
          Sale(restaurantId: 1, date: DateTime(2026, 10, 17), lines: [line]);
      expect(
        () => SaleService.validate(
          invalidSale(
            const SaleLine(designation: 'Article', quantity: 0, unitPrice: 100),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => SaleService.validate(
          invalidSale(
            const SaleLine(designation: 'Article', quantity: 1, unitPrice: -1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => SaleService.validate(
          invalidSale(
            const SaleLine(designation: ' ', quantity: 1, unitPrice: 100),
          ),
        ),
        throwsArgumentError,
      );
    });
    test('une vente doit référencer un plat du catalogue', () {
      expect(
        () => SaleService.validate(
          Sale(
            restaurantId: 1,
            date: DateTime(2026, 10, 17),
            lines: const [
              SaleLine(designation: 'Plat', quantity: 1, unitPrice: 1000),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });
  });
  test('un achat exige au moins un produit', () {
    final purchase = Purchase(
      supplierId: 1,
      restaurantId: 1,
      date: DateTime(2026),
      expectedDate: DateTime(2026),
      lines: [],
    );
    expect(() => PurchaseService.validate(purchase), throwsArgumentError);
  });
}
