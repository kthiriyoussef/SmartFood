class JobOffer {
  const JobOffer({
    required this.id,
    required this.title,
    required this.contractType,
    this.salary,
    this.requirements,
    this.restaurantName,
    this.isActive = true,
    this.applicationsCount = 0,
    this.requiredSkills = const [],
    this.minExperienceYears = 0,
  });

  final String id;
  final String title;
  final String contractType; // CDI, CDD, EXTRA
  final String? salary;
  final String? requirements;
  final String? restaurantName;
  final bool isActive;
  final int applicationsCount;
  final List<String> requiredSkills;
  final int minExperienceYears;

  JobOffer copyWith({bool? isActive}) {
    return JobOffer(
      id: id,
      title: title,
      contractType: contractType,
      salary: salary,
      requirements: requirements,
      restaurantName: restaurantName,
      isActive: isActive ?? this.isActive,
      applicationsCount: applicationsCount,
      requiredSkills: requiredSkills,
      minExperienceYears: minExperienceYears,
    );
  }
}