import 'package:smartfood/features/recruitment/models/job_application.dart';
import 'package:smartfood/features/recruitment/services/recruitment_data.dart';

/// Service en mémoire partagé par tous les écrans (singleton).
class ApplicationService {
  ApplicationService._();
  static final ApplicationService instance = ApplicationService._();

  final List<JobApplication> _applications = [];

  List<JobApplication> get all => List.unmodifiable(_applications);

  List<JobApplication> forOffer(String offerId) =>
      _applications.where((a) => a.offerId == offerId).toList();

  /// Candidatures d'un candidat, retrouvées par son téléphone.
  List<JobApplication> forPhone(String phoneNumber) => _applications
      .where((a) => a.phoneNumber == phoneNumber.trim())
      .toList();

  int countForOffer(String offerId) => forOffer(offerId).length;

  /// Règle métier : une seule candidature par offre et par candidat.
  bool hasAlreadyApplied({
    required String offerId,
    required String phoneNumber,
  }) {
    return _applications.any(
          (a) => a.offerId == offerId && a.phoneNumber == phoneNumber,
    );
  }

  /// Retourne null si tout va bien, sinon le message d'erreur.
  String? submit(JobApplication application) {
    // Règle métier : pas de candidature sur une offre fermée.
    JobOfferLookup? offer;
    for (final o in RecruitmentData.offers) {
      if (o.id == application.offerId) {
        offer = JobOfferLookup(o.isActive);
        break;
      }
    }
    if (offer != null && !offer.isActive) {
      return 'Cette offre est fermée.';
    }

    final phone = application.phoneNumber;
    if (phone != null &&
        hasAlreadyApplied(offerId: application.offerId, phoneNumber: phone)) {
      return 'Vous avez déjà postulé à cette offre.';
    }

    _applications.add(application);
    return null;
  }

  /// Machine à états : transitions autorisées.
  static const Map<String, List<String>> _transitions = {
    ApplicationStatus.received: [
      ApplicationStatus.shortlisted,
      ApplicationStatus.rejected,
    ],
    ApplicationStatus.shortlisted: [
      ApplicationStatus.accepted,
      ApplicationStatus.rejected,
    ],
    ApplicationStatus.accepted: [],
    ApplicationStatus.rejected: [],
  };

  List<String> allowedNext(String status) => _transitions[status] ?? const [];

  /// Retourne null si OK, sinon un message d'erreur.
  String? changeStatus(String applicationId, String newStatus) {
    final index = _applications.indexWhere((a) => a.id == applicationId);
    if (index == -1) return 'Candidature introuvable.';

    final current = _applications[index];
    if (!allowedNext(current.status).contains(newStatus)) {
      return 'Changement de statut non autorisé.';
    }

    _applications[index] = current.copyWith(status: newStatus);
    return null;
  }
}

/// Petit objet interne pour éviter les types nullables complexes.
class JobOfferLookup {
  const JobOfferLookup(this.isActive);
  final bool isActive;
}