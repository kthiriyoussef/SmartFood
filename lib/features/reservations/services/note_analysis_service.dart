import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:smartfood/features/reservations/models/note_analysis.dart';

/// Analyse la note libre du client (allergies, demandes, retard) avec
/// l'API Gemini de Google.
///
/// La clé n'est PAS dans le code : elle est passée au lancement avec
/// `flutter run --dart-define-from-file=env.json` (fichier ignoré par Git).
///
/// Sans clé, sans réseau ou en cas d'erreur de Gemini, l'analyse locale par
/// mots-clés prend le relais : l'application fonctionne toujours.
class NoteAnalysisService {
  NoteAnalysisService({http.Client? client, String? apiKey, String? model})
      : _client = client,
        _apiKey = apiKey ?? _envApiKey,
        _model = model ?? _envModel;

  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );
  static const Duration timeout = Duration(seconds: 12);

  final http.Client? _client;
  final String _apiKey;
  final String _model;

  bool get geminiEnabled =>
      _apiKey.isNotEmpty && !_apiKey.startsWith('colle-ta-cle');

  /// Analyse une note ; ne lève jamais d'exception.
  ///
  /// Règle : note vide (ou seulement des espaces) → AUCUN appel à Gemini.
  /// Note remplie → appel direct à l'API Gemini depuis l'application.
  Future<NoteAnalysis> analyze(String note) async {
    if (note.trim().isEmpty) return const NoteAnalysis();
    final local = analyzeLocally(note);
    if (!geminiEnabled) return local;
    try {
      final fromGemini = await _askGemini(note);
      return mergeWithLocal(fromGemini, local);
    } catch (error) {
      debugPrint('Gemini indisponible, analyse locale utilisée : $error');
      return local;
    }
  }

  // ------------------------------------------------------------- Gemini

  static const String _instructions = '''
Tu aides la cuisine d'un restaurant tunisien. On te donne la note libre
qu'un client a laissée avec sa réservation (français, arabe tunisien ou
anglais). Extrais :
- allergies : les allergènes ou intolérances mentionnés (ex. "arachides",
  "gluten", "lactose"), en français, au pluriel si naturel. Vide si aucun.
- modifications : les demandes sur la préparation (ex. "sans oignons",
  "bien cuit", "sauce à part"), courtes, en français. Pas les allergies.
- retard_minutes : le retard annoncé en minutes, ou null.
- priorite : "haute" s'il y a une allergie ou un risque pour la santé,
  sinon "normale".
- resume_cuisine : une consigne de 12 mots maximum pour le cuisinier,
  commençant par "⚠ Allergie" s'il y a une allergie. Chaîne vide si la
  note ne contient rien d'utile pour la cuisine.
N'invente rien qui ne soit pas dans la note.''';

  static const Map<String, Object?> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'allergies': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'modifications': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'retard_minutes': {'type': 'INTEGER', 'nullable': true},
      'priorite': {
        'type': 'STRING',
        'enum': ['haute', 'normale'],
      },
      'resume_cuisine': {'type': 'STRING'},
    },
    'required': [
      'allergies',
      'modifications',
      'retard_minutes',
      'priorite',
      'resume_cuisine',
    ],
  };

  Future<NoteAnalysis> _askGemini(String note) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent',
    );
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _instructions},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Note du client : « $note »'},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    });

    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'HTTP ${response.statusCode} : ${response.body}',
          uri,
        );
      }
      return parseGeminiResponse(utf8.decode(response.bodyBytes));
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Extrait le JSON produit par Gemini de la réponse `generateContent`.
  @visibleForTesting
  static NoteAnalysis parseGeminiResponse(String body) {
    final json = jsonDecode(body) as Map<String, Object?>;
    final candidates = json['candidates'] as List?;
    final parts =
        ((candidates?.first as Map?)?['content'] as Map?)?['parts'] as List?;
    final text = (parts?.first as Map?)?['text'] as String?;
    if (text == null) {
      throw const FormatException('Réponse Gemini sans texte');
    }
    final data = jsonDecode(text);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Réponse Gemini inattendue');
    }
    return NoteAnalysis.fromJson(data, source: NoteAnalysisSource.gemini);
  }

  /// Filet de sécurité : si les mots-clés locaux trouvent une allergie que
  /// Gemini n'a pas signalée, on l'ajoute (mieux vaut une alerte de trop).
  @visibleForTesting
  static NoteAnalysis mergeWithLocal(NoteAnalysis gemini, NoteAnalysis local) {
    if (gemini.hasAllergy || !local.hasAllergy) return gemini;
    return NoteAnalysis(
      allergies: local.allergies,
      modifications: gemini.modifications,
      lateMinutes: gemini.lateMinutes ?? local.lateMinutes,
      highPriority: true,
      kitchenSummary: local.kitchenSummary,
      source: NoteAnalysisSource.gemini,
    );
  }

  // ------------------------------------------------------ Analyse locale

  /// Allergène affiché → mots-clés (sans accents, en minuscules).
  static const Map<String, List<String>> _allergens = {
    'arachides': ['arachide', 'cacahuete', 'cacahouete', 'peanut', 'kakaouia'],
    'gluten': ['gluten', 'celiaque', 'coeliaque', 'coliaque', 'ble'],
    'lactose': ['lactose', 'lait', 'laitier', 'laitiers', 'dairy'],
    // « œ » est normalisé en « o » (longueur conservée) : œuf → ouf.
    'œufs': ['oeuf', 'ouf', 'egg', 'eggs'],
    'fruits de mer': [
      'fruits de mer',
      'crevette',
      'crustace',
      'moule',
      'seafood'
    ],
    'poisson': ['poisson', 'thon', 'fish'],
    'fruits à coque': ['noix', 'amande', 'noisette', 'pistache', 'nuts'],
    'sésame': ['sesame'],
    'soja': ['soja', 'soy'],
    'moutarde': ['moutarde', 'mustard'],
    'céleri': ['celeri', 'celery'],
  };

  static final RegExp _allergyTrigger = RegExp(
    r'allerg|intoleran|celiaque|coeliaque|coliaque|ne supporte pas|'
    r'choc anaphylactique',
  );

  static final RegExp _modification = RegExp(
    r"\b(sans|pas de|pas d'|avec|bien|peu|tres|extra|plus de|moins de|"
    r"sauce a part|a part)\b[^,.;!?\n]*",
  );

  static final List<RegExp> _late = [
    RegExp(r'retard\D{0,20}?(\d{1,3})\s*(min|mn|minutes?)\b'),
    RegExp(r'(\d{1,3})\s*(min|mn|minutes?)\D{0,20}?retard'),
  ];

  /// Analyse hors ligne par mots-clés (secours de Gemini).
  static NoteAnalysis analyzeLocally(String note) {
    final text = normalize(note);

    final allergies = <String>[];
    if (_allergyTrigger.hasMatch(text)) {
      _allergens.forEach((label, keywords) {
        final found = keywords.any(
          (k) => RegExp('\\b${RegExp.escape(k)}s?\\b').hasMatch(text),
        );
        if (found) allergies.add(label);
      });
    }

    // normalize() conserve la longueur : les positions trouvées dans le
    // texte normalisé correspondent au texte d'origine.
    final modifications = <String>[];
    for (final match in _modification.allMatches(text)) {
      final fragment = match.group(0)!;
      if (_allergyTrigger.hasMatch(fragment) || fragment.contains('retard')) {
        continue;
      }
      final original = note.substring(match.start, match.end).trim();
      if (original.split(' ').length < 2 || original.length > 40) continue;
      modifications.add(original);
    }

    int? lateMinutes;
    for (final pattern in _late) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        lateMinutes = int.tryParse(m.group(1)!);
        break;
      }
    }

    final summary = [
      if (allergies.isNotEmpty) '⚠ Allergie : ${allergies.join(', ')}',
      ...modifications,
      if (lateMinutes != null) 'retard $lateMinutes min',
    ].join(' — ');

    return NoteAnalysis(
      allergies: allergies,
      modifications: modifications,
      lateMinutes: lateMinutes,
      highPriority: allergies.isNotEmpty,
      kitchenSummary: summary,
      source: NoteAnalysisSource.local,
    );
  }

  /// Minuscules sans accents, MÊME longueur que le texte d'origine.
  @visibleForTesting
  static String normalize(String input) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝŸŒÆ’';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoaAAAAAACEEEEIIIINOOOOOUUUUYYOA\'';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString().toLowerCase();
  }
}
