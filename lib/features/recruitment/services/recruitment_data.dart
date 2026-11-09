import 'package:flutter/foundation.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';

/// Données de test partagées par les écrans du module (en mémoire).
class RecruitmentData {
  /// Change à chaque modification : les écrans qui l'écoutent se rafraîchissent.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void _notify() => changes.value++;

  static final List<JobOffer> offers = [
    const JobOffer(
      id: 'O-101',
      title: 'Serveur / Serveuse',
      contractType: 'CDI',
      salary: '900 DT / mois',
      requirements: 'Expérience en salle, bon contact client.',
      requiredSkills: ['Service en salle', 'Accueil client', 'Caisse'],
      minExperienceYears: 1,
    ),
    const JobOffer(
      id: 'O-102',
      title: 'Cuisinier(ère)',
      contractType: 'CDD',
      salary: '1200 DT / mois',
      requirements: 'Cuisine méditerranéenne, travail en équipe.',
      requiredSkills: ['Cuisine', 'Hygiène alimentaire'],
      minExperienceYears: 2,
    ),
    const JobOffer(
      id: 'O-103',
      title: 'Livreur',
      contractType: 'EXTRA',
      salary: '15 DT / heure',
      isActive: false,
      requiredSkills: ['Livraison'],
    ),
  ];

  /// Ajoute une offre en tête de liste.
  static void addOffer(JobOffer offer) {
    offers.insert(0, offer);
    _notify();
  }

  /// Ferme ou rouvre une offre.
  static void setActive(String offerId, bool active) {
    final index = offers.indexWhere((o) => o.id == offerId);
    if (index == -1) return;
    offers[index] = offers[index].copyWith(isActive: active);
    _notify();
  }
}