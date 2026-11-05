import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:smartfood/core/database/database_helper.dart';
import 'package:smartfood/features/users/models/client_profile.dart';

/// Une seule ligne (id = 1) : le profil du client de cet appareil.
class ClientProfileRepository {
  /// Notifie les écrans quand le profil change (formulaire, onglet Profil).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<Database> get _database => DatabaseHelper.instance.database;

  Future<ClientProfile?> get() async {
    final rows = await (await _database).query(
      'profil_client',
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : ClientProfile.fromMap(rows.first);
  }

  Future<void> save(ClientProfile profile) async {
    await (await _database).insert(
      'profil_client',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    changes.value++;
  }

  Future<void> clear() async {
    await (await _database).delete('profil_client');
    changes.value++;
  }
}
