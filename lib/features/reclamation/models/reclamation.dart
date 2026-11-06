class Reclamation {
  const Reclamation({
    required this.id,
    required this.motif,
    required this.description,
    required this.status,
    required this.createdAt,
    this.reservationRef,
    this.restaurantName,
    this.justificatifName,
    this.justificatifPath,
    this.decision,
    this.montantRembourse,
    this.priorite = 'MOYENNE',
    this.impact = 'NORMAL',
  });

  // ==============================
  // INFORMATIONS GENERALES
  // ==============================

  final String id;
  final String motif;
  final String description;
  final String status;
  final String createdAt;

  // ==============================
  // INFORMATIONS COMPLEMENTAIRES
  // ==============================

  final String? reservationRef;
  final String? restaurantName;
  final String? justificatifName;
  final String? justificatifPath;
  final String? decision;
  final double? montantRembourse;

  // ==============================
  // METIER AVANCE : PRIORITE
  // ==============================

  final String priorite;
  final String impact;

  // ==============================
  // LIBELLES POUR L'INTERFACE
  // ==============================

  String get prioriteLabel {
    switch (priorite) {
      case 'FAIBLE':
        return 'Faible';
      case 'MOYENNE':
        return 'Moyenne';
      case 'ELEVEE':
        return 'Élevée';
      case 'URGENTE':
        return 'Urgente';
      default:
        return priorite;
    }
  }

  String get impactLabel {
    switch (impact) {
      case 'FORT':
        return 'Impact important';
      case 'NORMAL':
        return 'Impact normal';
      default:
        return impact;
    }
  }

  bool get isUrgente => priorite == 'URGENTE';

  bool get isEnCours => status == 'EN_ATTENTE' || status == 'EN_COURS';

  bool get isTerminee => status == 'RESOLUE' || status == 'REJETEE';

  // ==============================
  // CONVERSION SQLITE -> OBJET
  // ==============================

  factory Reclamation.fromMap(Map<String, Object?> row) {
    final rawDate = row['date_creation']?.toString() ?? '';

    final parsedDate = DateTime.tryParse(rawDate);

    final formattedDate = parsedDate == null
        ? rawDate
        : '${parsedDate.day.toString().padLeft(2, '0')}/'
            '${parsedDate.month.toString().padLeft(2, '0')}/'
            '${parsedDate.year}';

    final rawAmount = row['montant_rembourse'];

    double? montantRembourse;

    if (rawAmount is num) {
      montantRembourse = rawAmount.toDouble();
    } else if (rawAmount is String) {
      montantRembourse = double.tryParse(rawAmount);
    }

    return Reclamation(
      id: 'T-${row['id']}',
      motif: row['sujet']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      status: row['statut']?.toString() ?? 'EN_ATTENTE',
      createdAt: formattedDate,
      reservationRef: row['reservation_ref']?.toString(),
      restaurantName: row['restaurant_nom']?.toString(),
      justificatifName: row['justificatif_name']?.toString(),
      justificatifPath: row['justificatif_path']?.toString(),
      decision: row['decision']?.toString(),
      montantRembourse: montantRembourse,
      priorite: row['priorite']?.toString() ?? 'MOYENNE',
      impact: row['impact']?.toString() ?? 'NORMAL',
    );
  }
}
