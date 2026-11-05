import 'package:flutter_test/flutter_test.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';

void main() {
  group('earliestPickup', () {
    test('ajoute le délai de préparation et arrondit à 5 min', () {
      final now = DateTime(2026, 11, 5, 12, 3);
      expect(ReservationService.earliestPickup(now: now),
          DateTime(2026, 11, 5, 12, 25));
    });
    test('avant l’ouverture → heure d’ouverture', () {
      final now = DateTime(2026, 11, 5, 6, 0);
      expect(ReservationService.earliestPickup(now: now),
          DateTime(2026, 11, 5, 8, 0));
    });
    test('après la fermeture → demain à l’ouverture', () {
      final now = DateTime(2026, 11, 5, 22, 50);
      expect(ReservationService.earliestPickup(now: now),
          DateTime(2026, 11, 6, 8, 0));
    });
  });

  group('validatePickup', () {
    final now = DateTime(2026, 11, 5, 12, 0);
    test('créneau valide', () {
      expect(
          ReservationService.validatePickup(DateTime(2026, 11, 5, 13),
              now: now),
          isNull);
    });
    test('trop tôt (préparation)', () {
      expect(
          ReservationService.validatePickup(DateTime(2026, 11, 5, 12, 10),
              now: now),
          isNotNull);
    });
    test('hors horaires', () {
      expect(
          ReservationService.validatePickup(DateTime(2026, 11, 6, 7), now: now),
          isNotNull);
    });
    test('après-demain refusé', () {
      expect(
          ReservationService.validatePickup(DateTime(2026, 11, 7, 12),
              now: now),
          isNotNull);
    });
  });

  test('téléphone tunisien = 8 chiffres', () {
    expect(ReservationService.validatePhone('22 345 678', '+216'), isNull);
    expect(ReservationService.validatePhone('2234567', '+216'), isNotNull);
    expect(ReservationService.validatePhone('612345678', '+33'), isNull);
  });

  test('noms', () {
    expect(ReservationService.validateName('Sonia', 'Prénom'), isNull);
    expect(ReservationService.validateName('Ben Ali', 'Nom'), isNull);
    expect(ReservationService.validateName('A', 'Nom'), isNotNull);
    expect(ReservationService.validateName('R2D2', 'Nom'), isNotNull);
  });

  test('plat réservable + quantité max', () {
    final restaurant = Restaurant(
        id: 1,
        nom: 'R',
        adresse: 'a',
        ville: 'v',
        telephone: 't',
        dateCreation: DateTime(2026));
    Menu menu(int q, {bool dispo = true}) => Menu(
        id: 1,
        restaurantId: 1,
        nom: 'P',
        prix: 10,
        categorie: 'Plat',
        quantite: q,
        disponible: dispo,
        dateCreation: DateTime(2026));
    expect(ReservationService.isMenuReservable(menu(3), restaurant), isTrue);
    expect(ReservationService.isMenuReservable(menu(0), restaurant), isFalse);
    expect(
        ReservationService.isMenuReservable(menu(5, dispo: false), restaurant),
        isFalse);
    expect(
        ReservationService.isMenuReservable(
            menu(5), restaurant.copyWith(statut: RestaurantStatus.archive)),
        isFalse);
    expect(ReservationService.maxQuantityFor(menu(3)), 3);
    expect(ReservationService.maxQuantityFor(menu(40)), 10);
  });

  test('format du créneau', () {
    final now = DateTime(2026, 11, 5, 9);
    expect(Reservation.formatPickup(DateTime(2026, 11, 5, 18, 30), now: now),
        'Aujourd’hui · 18h30');
    expect(Reservation.formatPickup(DateTime(2026, 11, 6, 8, 5), now: now),
        'Demain · 08h05');
  });

  test('étape suivante : jamais « Récupérée » sans PIN / QR', () {
    expect(ReservationService.nextStatus(ReservationStatus.enAttente),
        ReservationStatus.confirmee);
    expect(ReservationService.nextStatus(ReservationStatus.confirmee),
        ReservationStatus.preparation);
    expect(ReservationService.nextStatus(ReservationStatus.preparation),
        ReservationStatus.prete);
    expect(ReservationService.nextStatus(ReservationStatus.prete), isNull);
    expect(ReservationService.nextStatus(ReservationStatus.recuperee), isNull);
    expect(ReservationService.nextStatus(ReservationStatus.annulee), isNull);
  });
}
