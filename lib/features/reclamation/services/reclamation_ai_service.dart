
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ReclamationAiResult {
  final String categorie;
  final String sentiment;
  final String prioriteSuggeree;
  final String resume;
  final String reponseSuggeree;

  ReclamationAiResult({
    required this.categorie,
    required this.sentiment,
    required this.prioriteSuggeree,
    required this.resume,
    required this.reponseSuggeree,
  });

  factory ReclamationAiResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return ReclamationAiResult(
      categorie: json['categorie'] as String,
      sentiment: json['sentiment'] as String,
      prioriteSuggeree:
      json['priorite_suggeree'] as String,
      resume: json['resume'] as String,
      reponseSuggeree:
      json['reponse_suggeree'] as String,
    );
  }
}

class ReclamationAiService {
  static String get baseUrl {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }

    return 'http://127.0.0.1:8001';
  }

  Future<ReclamationAiResult> analyser({
    required String description,
    required String motif,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reclamations/analyser'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'description': description,
        'motif': motif,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur API (${response.statusCode}) : ${response.body}',
      );
    }

    return ReclamationAiResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
