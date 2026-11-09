import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfood/features/reservations/models/note_analysis.dart';
import 'package:smartfood/features/reservations/services/note_analysis_service.dart';

/// Construit une réponse `generateContent` comme celle de Gemini.
String geminiBody(Map<String, Object?> data) => jsonEncode({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': jsonEncode(data)},
            ],
          },
        },
      ],
    });

void main() {
  group('Analyse locale (secours)', () {
    test('détecte une allergie, une modification et un retard', () {
      final a = NoteAnalysisService.analyzeLocally(
        'Sans oignons svp, mon fils est allergique aux arachides, '
        "j'arrive avec 10 min de retard",
      );
      expect(a.allergies, ['arachides']);
      expect(a.modifications, contains('Sans oignons svp'));
      expect(a.lateMinutes, 10);
      expect(a.highPriority, isTrue);
      expect(a.kitchenSummary, startsWith('⚠ Allergie : arachides'));
      expect(a.source, NoteAnalysisSource.local);
    });

    test('gère les accents et la cœliaquie', () {
      final a = NoteAnalysisService.analyzeLocally(
        'Je suis cœliaque, intolérance au lait aussi',
      );
      expect(a.allergies, containsAll(['gluten', 'lactose']));
    });

    test('« sans fromage » est une modification, pas une allergie', () {
      final a = NoteAnalysisService.analyzeLocally('Sans fromage, bien cuit');
      expect(a.allergies, isEmpty);
      expect(a.highPriority, isFalse);
      expect(a.modifications, ['Sans fromage', 'bien cuit']);
    });

    test('note sans information utile', () {
      final a = NoteAnalysisService.analyzeLocally('Merci beaucoup !');
      expect(a.isEmpty, isTrue);
    });

    test('normalize conserve la longueur', () {
      const text = 'Œuf, crème brûlée, très épicé’';
      expect(NoteAnalysisService.normalize(text).length, text.length);
    });
  });

  group('Gemini', () {
    test('lit la réponse JSON structurée', () {
      final a = NoteAnalysisService.parseGeminiResponse(geminiBody({
        'allergies': ['gluten'],
        'modifications': ['sauce à part'],
        'retard_minutes': null,
        'priorite': 'haute',
        'resume_cuisine': '⚠ Allergie gluten — sauce à part',
      }));
      expect(a.allergies, ['gluten']);
      expect(a.modifications, ['sauce à part']);
      expect(a.lateMinutes, isNull);
      expect(a.highPriority, isTrue);
      expect(a.source, NoteAnalysisSource.gemini);
    });

    test('envoie la clé et utilise la réponse de Gemini', () async {
      late http.Request sent;
      final service = NoteAnalysisService(
        apiKey: 'test-key',
        model: 'gemini-test',
        client: MockClient((request) async {
          sent = request;
          return http.Response.bytes(
            utf8.encode(geminiBody({
              'allergies': [],
              'modifications': ['bien cuit'],
              'retard_minutes': 5,
              'priorite': 'normale',
              'resume_cuisine': 'Bien cuit',
            })),
            200,
          );
        }),
      );

      final a = await service.analyze('Bien cuit, 5 min de retard');
      expect(sent.headers['x-goog-api-key'], 'test-key');
      expect(sent.url.path, contains('gemini-test:generateContent'));
      expect(a.source, NoteAnalysisSource.gemini);
      expect(a.modifications, ['bien cuit']);
      expect(a.lateMinutes, 5);
    });

    test('ajoute une allergie oubliée par Gemini (filet de sécurité)', () async {
      final service = NoteAnalysisService(
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response(
              geminiBody({
                'allergies': [],
                'modifications': [],
                'retard_minutes': null,
                'priorite': 'normale',
                'resume_cuisine': '',
              }),
              200,
            )),
      );
      final a = await service.analyze('Allergie aux crevettes');
      expect(a.allergies, ['fruits de mer']);
      expect(a.highPriority, isTrue);
    });

    test('bascule sur l’analyse locale si Gemini échoue', () async {
      final service = NoteAnalysisService(
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response('quota', 429)),
      );
      final a = await service.analyze('Allergique au gluten');
      expect(a.source, NoteAnalysisSource.local);
      expect(a.allergies, ['gluten']);
    });

    test('note vide : aucun appel à Gemini', () async {
      var calls = 0;
      final service = NoteAnalysisService(
        apiKey: 'test-key',
        client: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      final a = await service.analyze('   ');
      expect(calls, 0);
      expect(a.isEmpty, isTrue);
    });

    test('sans clé : aucun appel réseau', () async {
      var called = false;
      final service = NoteAnalysisService(
        apiKey: '',
        client: MockClient((_) async {
          called = true;
          return http.Response('', 200);
        }),
      );
      expect(service.geminiEnabled, isFalse);
      await service.analyze('Sans sel');
      expect(called, isFalse);
    });
  });

  test('NoteAnalysis : aller-retour JSON', () {
    const a = NoteAnalysis(
      allergies: ['soja'],
      modifications: ['sans sel'],
      lateMinutes: 15,
      highPriority: true,
      kitchenSummary: '⚠ Allergie soja',
      source: NoteAnalysisSource.gemini,
    );
    final b = NoteAnalysis.decode(a.encode())!;
    expect(b.allergies, a.allergies);
    expect(b.modifications, a.modifications);
    expect(b.lateMinutes, 15);
    expect(b.source, NoteAnalysisSource.gemini);
    expect(NoteAnalysis.decode('pas du json'), isNull);
  });
}
