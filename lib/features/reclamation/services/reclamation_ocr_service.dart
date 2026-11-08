import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReclamationOcrResult {
  final String texteComplet;
  final String? reference;
  final String? date;
  final String? montant;

  const ReclamationOcrResult({
    required this.texteComplet,
    this.reference,
    this.date,
    this.montant,
  });
}

class ReclamationOcrService {
  Future<ReclamationOcrResult> scanner(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw StateError('Image introuvable.');
    }

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final image = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(image);
      final texte = result.text.trim();

      if (texte.isEmpty) {
        throw StateError(
          'Aucun texte détecté. Prenez une photo plus nette.',
        );
      }

      return ReclamationOcrResult(
        texteComplet: texte,
        reference: _extraireReference(texte),
        date: _extraireDate(texte),
        montant: _extraireMontant(texte),
      );
    } finally {
      await recognizer.close();
    }
  }

  String? _extraireReference(String texte) {
    final lignes = texte.split(RegExp(r'\r?\n'));

    final pattern = RegExp(
      r'(?:commande|réservation|reservation|ticket|réf(?:érence)?|ref)'
      r'\s*(?:n[°o.]?\s*)?[:#\-]?\s*'
      r'([A-Z0-9]+(?:[-/][A-Z0-9]+)+|[A-Z]*\d{3,})',
      caseSensitive: false,
    );

    for (final ligne in lignes) {
      final match = pattern.firstMatch(ligne.trim());

      if (match != null) {
        return match.group(1)?.toUpperCase();
      }
    }

    return null;
  }

  String? _extraireDate(String texte) {
    final pattern = RegExp(
      r'\b(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4})\b',
    );

    return pattern.firstMatch(texte)?.group(1);
  }

  String? _extraireMontant(String texte) {
    final lignes = texte.split(RegExp(r'\r?\n'));

    final pattern = RegExp(
      r'(\d+(?:[.,]\d{2,3})?)\s*(?:DT|TND|DINARS?)?',
      caseSensitive: false,
    );

    for (final ligne in lignes.reversed) {
      if (!RegExp(
        r'\b(total|net à payer|montant)\b',
        caseSensitive: false,
      ).hasMatch(ligne)) {
        continue;
      }

      final matches = pattern.allMatches(ligne).toList();

      if (matches.isNotEmpty) {
        return matches.last.group(1);
      }
    }

    return null;
  }
}
