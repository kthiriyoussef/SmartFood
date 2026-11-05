import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/repositories/reservation_repository.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';

export 'package:smartfood/features/reservations/repositories/reservation_repository.dart'
    show ReservationException;

/// Règles métier des réservations. Les écrans passent toujours par ici,
/// jamais directement par le repository.
class ReservationService {
  ReservationService({ReservationRepository? repository})
      : _repository = repository ?? ReservationRepository();

  final ReservationRepository _repository;

  /// Incrémenté à chaque création / annulation / changement de statut.
  /// Les écrans (onglet « Mes réservations », badge) l'écoutent pour se
  /// rafraîchir automatiquement.
  static ValueNotifier<int> get changes => DataChanges.reservations;

  static void _notifyChange() => DataChanges.reservationsChanged();
  final Random _random = Random.secure();

  /// Horaires de retrait acceptés (le modèle Restaurant n'a pas encore
  /// d'horaires propres).
  static const int openingHour = 8;
  static const int closingHour = 23;

  /// Délai minimal entre la réservation et le retrait (temps de préparation).
  static const Duration preparationDelay = Duration(minutes: 20);

  /// Nombre maximum de portions d'un même plat par réservation.
  static const int maxQuantityPerReservation = 10;

  /// Le retrait peut être réservé pour aujourd'hui ou demain.
  static const int bookingDaysAhead = 1;

  // ---------------------------------------------------------------- Règles

  static bool isMenuReservable(Menu menu, Restaurant restaurant) =>
      restaurant.statut == RestaurantStatus.actif &&
      menu.disponible &&
      menu.quantite > 0;

  static int maxQuantityFor(Menu menu) =>
      min(menu.quantite, maxQuantityPerReservation);

  /// Premier créneau possible : maintenant + délai, arrondi aux 5 minutes
  /// supérieures, et ramené dans les horaires d'ouverture.
  /// Retourne null si plus aucun créneau n'est disponible (aujourd'hui et demain).
  static DateTime? earliestPickup({DateTime? now}) {
    final reference = now ?? DateTime.now();
    var candidate = reference.add(preparationDelay);
    final extra = (5 - candidate.minute % 5) % 5;
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      candidate.hour,
      candidate.minute + extra,
    );

    final opening =
        DateTime(candidate.year, candidate.month, candidate.day, openingHour);
    if (candidate.isBefore(opening)) return opening;

    final closing =
        DateTime(candidate.year, candidate.month, candidate.day, closingHour);
    if (candidate.isAfter(closing)) {
      final nextOpening = opening.add(const Duration(days: 1));
      final lastDay = DateTime(reference.year, reference.month, reference.day)
          .add(const Duration(days: bookingDaysAhead));
      return nextOpening.isAfter(lastDay.add(const Duration(days: 1)))
          ? null
          : nextOpening;
    }
    return candidate;
  }

  /// Retourne un message d'erreur, ou null si le créneau est valide.
  static String? validatePickup(DateTime pickup, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final lastDay = today.add(const Duration(days: bookingDaysAhead));
    final day = DateTime(pickup.year, pickup.month, pickup.day);

    if (day.isBefore(today) || day.isAfter(lastDay)) {
      return 'Le retrait doit être prévu aujourd’hui ou demain.';
    }
    final minutes = pickup.hour * 60 + pickup.minute;
    if (minutes < openingHour * 60 || minutes > closingHour * 60) {
      return 'Retrait possible entre ${openingHour}h00 et ${closingHour}h00.';
    }
    if (pickup.isBefore(reference.add(preparationDelay))) {
      return 'Prévoyez au moins ${preparationDelay.inMinutes} minutes '
          'pour la préparation.';
    }
    return null;
  }

  static String? validateName(String? value, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field obligatoire';
    if (text.length < 2) return '$field trop court';
    if (!RegExp(r"^[\p{L}][\p{L}\s'’-]*$", unicode: true).hasMatch(text)) {
      return '$field : lettres uniquement';
    }
    return null;
  }

  /// [dialCode] ex. « +216 ». La Tunisie impose 8 chiffres.
  static String? validatePhone(String? value, String dialCode) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s.-]'), '');
    if (digits.isEmpty) return 'Numéro obligatoire';
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Chiffres uniquement';
    if (dialCode == '+216' && digits.length != 8) {
      return 'Un numéro tunisien contient 8 chiffres';
    }
    if (digits.length < 6 || digits.length > 12) return 'Numéro invalide';
    return null;
  }

  // ------------------------------------------------------------- Actions

  Future<Reservation> createReservation({
    required Menu menu,
    required Restaurant restaurant,
    required int quantity,
    required DateTime pickupAt,
    required String firstName,
    required String lastName,
    required String dialCode,
    required String phone,
    String? note,
  }) async {
    if (menu.id == null || restaurant.id == null) {
      throw const ReservationException('Plat ou restaurant introuvable.');
    }
    if (!isMenuReservable(menu, restaurant)) {
      throw const ReservationException('Ce plat n’est plus disponible.');
    }
    if (quantity < 1 || quantity > maxQuantityPerReservation) {
      throw const ReservationException('Quantité invalide.');
    }
    final error = validateName(firstName, 'Prénom') ??
        validateName(lastName, 'Nom') ??
        validatePhone(phone, dialCode) ??
        validatePickup(pickupAt);
    if (error != null) throw ReservationException(error);

    final cleanNote = note?.trim();
    final reservation = Reservation(
      reference: await _generateReference(),
      menuId: menu.id,
      restaurantId: restaurant.id,
      restaurantName: restaurant.nom,
      dishName: menu.nom,
      unitPrice: menu.prix,
      quantity: quantity,
      clientFirstName: _capitalize(firstName),
      clientLastName: _capitalize(lastName),
      phoneNumber: '$dialCode ${phone.replaceAll(RegExp(r'[\s.-]'), '')}',
      note: cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
      pickupAt: pickupAt,
      pinCode: _generatePin(),
      createdAt: DateTime.now(),
    );

    // Le stock est revérifié et décrémenté dans la transaction.
    final created = await _repository.createWithStock(reservation);
    _notifyChange();
    return created;
  }

  Future<List<Reservation>> getReservations({int? restaurantId}) =>
      _repository.getAll(restaurantId: restaurantId);

  Future<Reservation?> getReservation(int id) => _repository.getById(id);

  Future<Reservation> cancelByClient(Reservation reservation) async {
    if (!reservation.canBeCancelledByClient) {
      throw const ReservationException(
        'La préparation a commencé : annulation impossible.',
      );
    }
    await _repository.cancelAndRestock(reservation);
    _notifyChange();
    return reservation.copyWith(status: ReservationStatus.annulee);
  }

  /// Le restaurant peut refuser / annuler tant que la commande n'est pas
  /// récupérée (rupture, fermeture…). Les portions sont remises en stock.
  Future<Reservation> cancelByRestaurant(Reservation reservation) async {
    if (!reservation.isActive) {
      throw const ReservationException(
        'Cette réservation est déjà clôturée.',
      );
    }
    await _repository.cancelAndRestock(reservation);
    _notifyChange();
    return reservation.copyWith(status: ReservationStatus.annulee);
  }

  /// Étape suivante du cycle (null si la prochaine étape est le retrait,
  /// qui exige le PIN ou le QR).
  static String? nextStatus(String status) => switch (status) {
        ReservationStatus.enAttente => ReservationStatus.confirmee,
        ReservationStatus.confirmee => ReservationStatus.preparation,
        ReservationStatus.preparation => ReservationStatus.prete,
        _ => null,
      };

  /// Le restaurant peut placer une réservation en cours sur n'importe quel
  /// statut non final (avancer ou corriger une erreur). Les statuts finaux
  /// sont protégés : RECUPEREE uniquement via [confirmPickup], ANNULEE via
  /// [cancelByRestaurant].
  Future<Reservation> advanceStatus(Reservation reservation, String to) async {
    if (!reservation.isActive ||
        !ReservationStatus.active.contains(to) ||
        to == reservation.status) {
      throw const ReservationException('Changement de statut non autorisé.');
    }
    await _repository.updateStatus(reservation.id!, reservation.status, to);
    _notifyChange();
    return reservation.copyWith(status: to);
  }

  /// Retrouve les réservations correspondant à un code présenté au comptoir
  /// (contenu du QR, référence ou PIN) pour un restaurant donné.
  /// Toutes les réservations trouvées sont renvoyées, prêtes ou non : l'écran
  /// explique alors pourquoi le retrait est impossible.
  Future<List<Reservation>> findByPickupCode(
    int restaurantId,
    String code,
  ) async {
    final value = code.trim();
    if (value.isEmpty) return const [];
    final all = await _repository.getAll(restaurantId: restaurantId);
    return all
        .where((r) =>
            r.status != ReservationStatus.annulee &&
            (value == qrPayload(r) ||
                value.toUpperCase() == r.reference ||
                value == r.pinCode))
        .toList();
  }

  /// Valide le retrait avec le PIN ou le contenu du QR code du client.
  Future<Reservation> confirmPickup(
      Reservation reservation, String code) async {
    if (reservation.status != ReservationStatus.prete) {
      throw const ReservationException('La commande n’est pas encore prête.');
    }
    final value = code.trim();
    final valid = value == reservation.pinCode ||
        value == reservation.reference ||
        value == qrPayload(reservation);
    if (!valid) {
      throw const ReservationException('Code invalide pour cette réservation.');
    }
    await _repository.updateStatus(
      reservation.id!,
      ReservationStatus.prete,
      ReservationStatus.recuperee,
    );
    _notifyChange();
    return reservation.copyWith(status: ReservationStatus.recuperee);
  }

  /// Contenu à encoder dans le QR code présenté par le client.
  static String qrPayload(Reservation reservation) =>
      'smartfood:${reservation.reference}:${reservation.pinCode}';

  // ------------------------------------------------------------ Helpers

  Future<String> _generateReference() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans 0/O/1/I
    while (true) {
      final code = List.generate(
        6,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final reference = 'SF-$code';
      if (!await _repository.referenceExists(reference)) return reference;
    }
  }

  String _generatePin() => _random.nextInt(10000).toString().padLeft(4, '0');

  static String _capitalize(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
