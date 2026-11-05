/// Profil du client enregistré sur l'appareil (pas encore de comptes).
/// Sert à pré-remplir le formulaire de réservation.
class ClientProfile {
  const ClientProfile({
    required this.firstName,
    required this.lastName,
    required this.dialCode,
    required this.phone,
  });

  final String firstName;
  final String lastName;

  /// Indicatif pays, ex. « +216 ».
  final String dialCode;

  /// Numéro sans indicatif, chiffres uniquement.
  final String phone;

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();

  String get fullPhone => '$dialCode $phone';

  Map<String, Object?> toMap() => {
        'id': 1,
        'prenom': firstName,
        'nom': lastName,
        'indicatif': dialCode,
        'telephone': phone,
      };

  factory ClientProfile.fromMap(Map<String, Object?> map) => ClientProfile(
        firstName: map['prenom'] as String,
        lastName: map['nom'] as String,
        dialCode: map['indicatif'] as String,
        phone: map['telephone'] as String,
      );
}

class CountryOption {
  const CountryOption({
    required this.code,
    required this.label,
    required this.flag,
  });

  final String code;
  final String label;
  final String flag;

  static const List<CountryOption> all = [
    CountryOption(code: '+216', label: 'Tunisie', flag: '🇹🇳'),
    CountryOption(code: '+33', label: 'France', flag: '🇫🇷'),
    CountryOption(code: '+213', label: 'Algérie', flag: '🇩🇿'),
    CountryOption(code: '+212', label: 'Maroc', flag: '🇲🇦'),
  ];

  static CountryOption byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);
}
