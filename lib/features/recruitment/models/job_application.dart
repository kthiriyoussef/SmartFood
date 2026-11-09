class ApplicationStatus {
  static const received = 'RECU';
  static const shortlisted = 'EN_RETENUE';
  static const accepted = 'ACCEPTE';
  static const rejected = 'REFUSE';
}

class Availability {
  static const fullTime = 'TEMPS_PLEIN';
  static const partTime = 'TEMPS_PARTIEL';
  static const weekend = 'WEEKEND';

  static const labels = {
    fullTime: 'Temps plein',
    partTime: 'Temps partiel',
    weekend: 'Week-end',
  };
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.offerId,
    required this.candidateName,
    required this.status,
    this.phoneNumber,
    this.cvUrl,
    this.motivation,
    this.skills = const [],
    this.experienceYears = 0,
    this.availability = Availability.fullTime,
  });

  final String id;
  final String offerId;
  final String candidateName;
  final String status;
  final String? phoneNumber;
  final String? cvUrl;
  final String? motivation;
  final List<String> skills;
  final int experienceYears;
  final String availability;

  JobApplication copyWith({String? status}) {
    return JobApplication(
      id: id,
      offerId: offerId,
      candidateName: candidateName,
      status: status ?? this.status,
      phoneNumber: phoneNumber,
      cvUrl: cvUrl,
      motivation: motivation,
      skills: skills,
      experienceYears: experienceYears,
      availability: availability,
    );
  }
}