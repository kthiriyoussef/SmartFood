import 'dart:convert';

/// Résultat de l'analyse de la note laissée par le client.
///
/// Produit par Gemini (ou, en secours, par l'analyse locale par mots-clés)
/// et stocké en JSON dans la colonne `reservations.analyse_note`.
class NoteAnalysis {
  const NoteAnalysis({
    this.allergies = const [],
    this.modifications = const [],
    this.lateMinutes,
    this.highPriority = false,
    this.kitchenSummary = '',
    this.source = NoteAnalysisSource.local,
  });

  /// Allergènes signalés (« arachides », « gluten »…).
  final List<String> allergies;

  /// Demandes sur la préparation (« sans oignons », « bien cuit »…).
  final List<String> modifications;

  /// Retard annoncé par le client, en minutes.
  final int? lateMinutes;

  /// Vrai dès qu'une allergie est détectée : la réservation passe en tête.
  final bool highPriority;

  /// Consigne courte destinée à la cuisine.
  final String kitchenSummary;

  /// `gemini` ou `local` : affiché pour savoir d'où vient l'analyse.
  final String source;

  bool get hasAllergy => allergies.isNotEmpty;

  bool get isEmpty =>
      allergies.isEmpty &&
      modifications.isEmpty &&
      lateMinutes == null &&
      kitchenSummary.isEmpty;

  Map<String, Object?> toJson() => {
        'allergies': allergies,
        'modifications': modifications,
        'retard_minutes': lateMinutes,
        'priorite': highPriority ? 'haute' : 'normale',
        'resume_cuisine': kitchenSummary,
        'source': source,
      };

  String encode() => jsonEncode(toJson());

  /// Lecture tolérante : un champ manquant ou mal typé ne fait pas planter.
  factory NoteAnalysis.fromJson(Map<String, Object?> json, {String? source}) {
    List<String> strings(Object? value) => value is List
        ? value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const [];

    final allergies = strings(json['allergies']);
    final late = json['retard_minutes'];
    final lateMinutes = late is num && late > 0 ? late.toInt() : null;
    return NoteAnalysis(
      allergies: allergies,
      modifications: strings(json['modifications']),
      lateMinutes: lateMinutes,
      highPriority: json['priorite'] == 'haute' || allergies.isNotEmpty,
      kitchenSummary: (json['resume_cuisine'] as String?)?.trim() ?? '',
      source: source ?? (json['source'] as String?) ?? NoteAnalysisSource.local,
    );
  }

  /// Renvoie null si le texte est absent ou illisible.
  static NoteAnalysis? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? NoteAnalysis.fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }
}

class NoteAnalysisSource {
  NoteAnalysisSource._();

  static const String gemini = 'gemini';
  static const String local = 'local';
}
