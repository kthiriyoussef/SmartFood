
import 'user_role.dart';

class User {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final String passwordHash;
  final UserRole role;
  final int? restaurantId;
  final bool actif;

  const User({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.restaurantId,
    this.actif = true,
  });

  String get nomComplet => '$prenom $nom';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'password_hash': passwordHash,
      'role': role.databaseValue,
      'restaurant_id': restaurantId,
      'actif': actif ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      role: UserRoleExtension.fromDatabase(
        map['role'] as String,
      ),
      restaurantId: map['restaurant_id'] as int?,
      actif: (map['actif'] as int) == 1,
    );
  }
}
