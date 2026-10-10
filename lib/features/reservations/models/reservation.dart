class Reservation {
  const Reservation({
    required this.id,
    required this.clientName,
    required this.pickupTime,
    required this.status,
    required this.pinCode,
    this.phoneNumber,
    this.restaurantName,
    this.dishNames,
    this.importantNote,
  });

  final String id;
  final String clientName;
  final String pickupTime;
  final String status;
  final String pinCode;
  final String? phoneNumber;
  final String? restaurantName;
  final String? dishNames;
  final String? importantNote;
}
