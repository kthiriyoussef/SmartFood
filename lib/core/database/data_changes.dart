import 'package:flutter/foundation.dart';

/// Signaux de modification des données. Les écrans les écoutent pour se
/// rafraîchir automatiquement, quel que soit l'écran qui a fait le changement
/// (ex. le restaurant confirme une réservation → l'onglet client se met à jour).
class DataChanges {
  DataChanges._();

  /// Restaurants et plats (fiche, carte, stock, disponibilité).
  static final ValueNotifier<int> catalog = ValueNotifier<int>(0);

  /// Réservations (création, statut, annulation).
  static final ValueNotifier<int> reservations = ValueNotifier<int>(0);

  static void catalogChanged() => catalog.value++;

  /// Une réservation modifie aussi le stock des plats.
  static void reservationsChanged() {
    reservations.value++;
    catalog.value++;
  }
}
