/// Statuts possibles d'une réservation, dans l'ordre du cycle de vie.
///
/// EN_ATTENTE → CONFIRMEE → PREPARATION → PRETE → RECUPEREE
/// ANNULEE peut intervenir tant que la réservation n'est pas en préparation.
class ReservationStatus {
  ReservationStatus._();

  static const String enAttente = 'EN_ATTENTE';
  static const String confirmee = 'CONFIRMEE';
  static const String preparation = 'PREPARATION';
  static const String prete = 'PRETE';
  static const String recuperee = 'RECUPEREE';
  static const String annulee = 'ANNULEE';

  /// Parcours « normal » géré par le restaurant.
  static const List<String> flow = [
    enAttente,
    confirmee,
    preparation,
    prete,
    recuperee,
  ];

  static const List<String> all = [...flow, annulee];

  static const Set<String> active = {enAttente, confirmee, preparation, prete};

  /// Le client ne peut annuler que tant que la cuisine n'a pas commencé.
  static const Set<String> cancellableByClient = {enAttente, confirmee};

  static String label(String status) => switch (status) {
        confirmee => 'Confirmée',
        preparation => 'En préparation',
        prete => 'Prête',
        recuperee => 'Récupérée',
        annulee => 'Annulée',
        _ => 'En attente',
      };
}

class Reservation {
  const Reservation({
    this.id,
    required this.reference,
    this.menuId,
    this.restaurantId,
    required this.restaurantName,
    required this.dishName,
    required this.unitPrice,
    required this.quantity,
    required this.clientFirstName,
    required this.clientLastName,
    required this.phoneNumber,
    this.note,
    required this.pickupAt,
    this.status = ReservationStatus.enAttente,
    required this.pinCode,
    required this.createdAt,
  });

  final int? id;

  /// Référence lisible communiquée au client (ex. SF-7K2Q9A).
  final String reference;

  /// Null si le plat ou le restaurant a été supprimé depuis.
  final int? menuId;
  final int? restaurantId;

  /// Instantané du nom et du prix au moment de la réservation : l'historique
  /// reste juste même si le restaurant modifie sa carte ensuite.
  final String restaurantName;
  final String dishName;
  final double unitPrice;
  final int quantity;

  final String clientFirstName;
  final String clientLastName;
  final String phoneNumber;
  final String? note;

  final DateTime pickupAt;
  final String status;
  final String pinCode;
  final DateTime createdAt;

  double get total => unitPrice * quantity;

  String get clientName => '$clientFirstName $clientLastName';

  String get dishNames => '$quantity × $dishName';

  String get statusLabel => ReservationStatus.label(status);

  bool get isActive => ReservationStatus.active.contains(status);

  bool get canBeCancelledByClient =>
      ReservationStatus.cancellableByClient.contains(status);

  /// Libellé du créneau de retrait : « Aujourd’hui · 18h30 », « Demain · 12h00 »…
  String get pickupTime => formatPickup(pickupAt);

  static String formatPickup(DateTime date, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final day = _dateOnly(date);
    final diff = day.difference(today).inDays;
    final time =
        '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
    final dayLabel = switch (diff) {
      0 => 'Aujourd’hui',
      1 => 'Demain',
      -1 => 'Hier',
      _ =>
        '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
    };
    return '$dayLabel · $time';
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'reference': reference,
        'menu_id': menuId,
        'restaurant_id': restaurantId,
        'restaurant_nom': restaurantName,
        'menu_nom': dishName,
        'prix_unitaire': unitPrice,
        'quantite': quantity,
        'client_prenom': clientFirstName,
        'client_nom': clientLastName,
        'telephone': phoneNumber,
        'note': note,
        'heure_retrait': pickupAt.toIso8601String(),
        'statut': status,
        'code_pin': pinCode,
        'date_creation': createdAt.toIso8601String(),
      };

  factory Reservation.fromMap(Map<String, Object?> map) {
    return Reservation(
      id: map['id'] as int,
      reference: map['reference'] as String,
      menuId: map['menu_id'] as int?,
      restaurantId: map['restaurant_id'] as int?,
      restaurantName: map['restaurant_nom'] as String,
      dishName: map['menu_nom'] as String,
      unitPrice: (map['prix_unitaire'] as num).toDouble(),
      quantity: (map['quantite'] as num).toInt(),
      clientFirstName: map['client_prenom'] as String,
      clientLastName: map['client_nom'] as String,
      phoneNumber: map['telephone'] as String,
      note: map['note'] as String?,
      pickupAt: DateTime.parse(map['heure_retrait'] as String),
      status: map['statut'] as String,
      pinCode: map['code_pin'] as String,
      createdAt: DateTime.parse(map['date_creation'] as String),
    );
  }

  Reservation copyWith({int? id, String? status}) {
    return Reservation(
      id: id ?? this.id,
      reference: reference,
      menuId: menuId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      dishName: dishName,
      unitPrice: unitPrice,
      quantity: quantity,
      clientFirstName: clientFirstName,
      clientLastName: clientLastName,
      phoneNumber: phoneNumber,
      note: note,
      pickupAt: pickupAt,
      status: status ?? this.status,
      pinCode: pinCode,
      createdAt: createdAt,
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
