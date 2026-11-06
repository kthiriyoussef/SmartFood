
enum UserRole {
  admin,
  restaurant,
  client,
}

extension UserRoleExtension on UserRole {
  String get databaseValue {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.restaurant:
        return 'RESTO';
      case UserRole.client:
        return 'CLIENT';
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.restaurant:
        return 'Directeur du restaurant';
      case UserRole.client:
        return 'Client';
    }
  }

  static UserRole fromDatabase(String value) {
    switch (value.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'RESTO':
        return UserRole.restaurant;
      case 'CLIENT':
        return UserRole.client;
      default:
        throw ArgumentError('Rôle inconnu : $value');
    }
  }
}
