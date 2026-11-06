import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';

class ReclamationRepository {
  ReclamationRepository({Database? testDatabase})
      : _testDatabase = testDatabase;

  final Database? _testDatabase;

  Future<Database> get _db async =>
      _testDatabase ?? await DatabaseHelper.instance.database;

  // ==========================
  // CONTROLE DES AUTORISATIONS
  // ==========================

  Future<void> _requireClient(Database db, int userId) async {
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'CLIENT' AND actif = 1",
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Compte CLIENT introuvable ou désactivé.');
    }
  }

  Future<void> _requireAdmin(Database db, int adminId) async {
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: "id = ? AND role = 'ADMIN' AND actif = 1",
      whereArgs: [adminId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Accès réservé à un ADMIN actif.');
    }
  }

  // ==========================
  // CALCUL AUTOMATIQUE
  // DE LA PRIORITE
  // ==========================

  static const Map<int, String> _priorityLevels = {
    0: 'FAIBLE',
    1: 'MOYENNE',
    2: 'ELEVEE',
    3: 'URGENTE',
  };

  static String calculatePriority({
    required String sujet,
    required String impact,
    required DateTime createdAt,
    DateTime? now,
  }) {
    final normalizedSubject = sujet.trim().toLowerCase();
    final normalizedImpact = impact.trim().toUpperCase();

    int score;

    switch (normalizedSubject) {
      case 'commande payée non reçue':
        score = 3;
        break;

      case 'plat non conforme':
      case 'annulation tardive':
      case 'retrait refusé au comptoir':
        score = 2;
        break;

      case 'quantité incorrecte':
        score = 1;
        break;

      default:
        score = 0;
    }

    if (normalizedImpact == 'FORT') {
      score += 1;
    }

    final currentDate = now ?? DateTime.now();
    final age = currentDate.difference(createdAt);

    if (!age.isNegative && age.inHours >= 72) {
      score += 1;
    }

    if (score > 3) {
      score = 3;
    }

    return _priorityLevels[score]!;
  }

  static int _priorityRank(String priority) {
    switch (priority) {
      case 'URGENTE':
        return 3;
      case 'ELEVEE':
        return 2;
      case 'MOYENNE':
        return 1;
      default:
        return 0;
    }
  }

  // ==========================
  // ACTUALISATION DES PRIORITES
  // ==========================

  Future<void> _refreshPriorities(Database db) async {
    final rows = await db.query(
      'reclamations',
      columns: [
        'id',
        'sujet',
        'impact',
        'priorite',
        'date_creation',
      ],
      where: "statut IN ('EN_ATTENTE', 'EN_COURS')",
    );

    final now = DateTime.now();

    final batch = db.batch();
    bool hasUpdates = false;

    for (final row in rows) {
      final createdAt = DateTime.tryParse(
        row['date_creation']?.toString() ?? '',
      );

      if (createdAt == null) {
        continue;
      }

      final calculatedPriority = calculatePriority(
        sujet: row['sujet']?.toString() ?? '',
        impact: row['impact']?.toString() ?? 'NORMAL',
        createdAt: createdAt,
        now: now,
      );

      final currentPriority = row['priorite']?.toString() ?? 'MOYENNE';

      if (calculatedPriority != currentPriority) {
        batch.update(
          'reclamations',
          {'priorite': calculatedPriority},
          where: 'id = ?',
          whereArgs: [row['id']],
        );

        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit(noResult: true);
    }
  }

  // ==========================
  // CREATION D'UNE RECLAMATION
  // ==========================

  Future<int> create({
    required int userId,
    required String sujet,
    required String description,
    String? reservationRef,
    String? justificatifPath,
    String? justificatifName,
    String impact = 'NORMAL',
  }) async {
    final db = await _db;
    await _requireClient(db, userId);

    if (sujet.trim().isEmpty) {
      throw ArgumentError('Choisissez un motif.');
    }

    if (description.trim().length < 10) {
      throw ArgumentError(
        'La description doit contenir au moins 10 caractères.',
      );
    }

    final normalizedImpact = impact.trim().toUpperCase();

    if (!{'NORMAL', 'FORT'}.contains(normalizedImpact)) {
      throw ArgumentError('Impact invalide.');
    }

    final now = DateTime.now();

    final priority = calculatePriority(
      sujet: sujet,
      impact: normalizedImpact,
      createdAt: now,
      now: now,
    );

    return db.insert('reclamations', {
      'user_id': userId,
      'sujet': sujet.trim(),
      'description': description.trim(),
      'reservation_ref': reservationRef?.trim().isEmpty == true
          ? null
          : reservationRef?.trim(),
      'statut': 'EN_ATTENTE',
      'priorite': priority,
      'impact': normalizedImpact,
      'justificatif_path': justificatifPath,
      'justificatif_name': justificatifName,
      'date_creation': now.toIso8601String(),
    });
  }

  // ==========================
  // HISTORIQUE CLIENT
  // ==========================

  Future<List<Map<String, Object?>>> history({
    required int userId,
  }) async {
    final db = await _db;
    await _requireClient(db, userId);

    await _refreshPriorities(db);

    return db.query(
      'reclamations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_creation DESC, id DESC',
    );
  }

  // ==========================
  // DETAILS CLIENT
  // ==========================

  Future<Map<String, Object?>?> details({
    required int userId,
    required int reclamationId,
  }) async {
    final db = await _db;
    await _requireClient(db, userId);

    await _refreshPriorities(db);

    final rows = await db.query(
      'reclamations',
      where: 'id = ? AND user_id = ?',
      whereArgs: [reclamationId, userId],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  // ==========================
  // LISTE ADMIN
  // ==========================

  Future<List<Map<String, Object?>>> allForAdmin({
    required int adminId,
  }) async {
    final db = await _db;
    await _requireAdmin(db, adminId);

    await _refreshPriorities(db);

    final rows = await db.query(
      'reclamations',
      orderBy: 'date_creation DESC, id DESC',
    );

    final result = List<Map<String, Object?>>.from(rows);

    result.sort((a, b) {
      final statusA = a['statut']?.toString() ?? '';
      final statusB = b['statut']?.toString() ?? '';

      final isOpenA = statusA == 'EN_ATTENTE' || statusA == 'EN_COURS';
      final isOpenB = statusB == 'EN_ATTENTE' || statusB == 'EN_COURS';

      if (isOpenA != isOpenB) {
        return isOpenA ? -1 : 1;
      }

      final rankA = _priorityRank(
        a['priorite']?.toString() ?? 'FAIBLE',
      );

      final rankB = _priorityRank(
        b['priorite']?.toString() ?? 'FAIBLE',
      );

      final priorityComparison = rankB.compareTo(rankA);

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      final dateA = a['date_creation']?.toString() ?? '';
      final dateB = b['date_creation']?.toString() ?? '';

      return dateB.compareTo(dateA);
    });

    return result;
  }

  // ==========================
  // MODIFICATION DU STATUT
  // ==========================

  Future<void> updateStatus({
    required int adminId,
    required int reclamationId,
    required String statut,
  }) async {
    const allowed = {
      'EN_ATTENTE',
      'EN_COURS',
      'RESOLUE',
      'REJETEE',
    };

    if (!allowed.contains(statut)) {
      throw ArgumentError('Statut invalide.');
    }

    final db = await _db;
    await _requireAdmin(db, adminId);

    // Met à jour la priorité avant une éventuelle clôture.
    await _refreshPriorities(db);

    final count = await db.update(
      'reclamations',
      {
        'statut': statut,
        'date_modification': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reclamationId],
    );

    if (count == 0) {
      throw StateError('Réclamation introuvable.');
    }
  }
}
