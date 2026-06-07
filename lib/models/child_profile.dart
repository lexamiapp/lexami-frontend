class CaseChildProfile {
  final String id;
  final String name;
  final String dob;
  final String school;
  final String grade;
  final String specialNeeds;
  final String dailyRoutine;
  final String currentLivingArrangement;
  final double distanceBetweenHomes;
  final String parentAWorkHours;
  final String parentBWorkHours;
  final Map<String, dynamic>? parentingPlan; // Store the generated plan here

  CaseChildProfile({
    required this.id,
    required this.name,
    required this.dob,
    this.school = '',
    this.grade = '',
    this.specialNeeds = '',
    this.dailyRoutine = '',
    this.currentLivingArrangement = 'Pending',
    this.distanceBetweenHomes = 0.0,
    this.parentAWorkHours = '',
    this.parentBWorkHours = '',
    this.parentingPlan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': dob,
      'school': school,
      'grade': grade,
      'specialNeeds': specialNeeds,
      'dailyRoutine': dailyRoutine,
      'currentLivingArrangement': currentLivingArrangement,
      'distanceBetweenHomes': distanceBetweenHomes,
      'parentAWorkHours': parentAWorkHours,
      'parentBWorkHours': parentBWorkHours,
      'parentingPlan': parentingPlan,
    };
  }

  factory CaseChildProfile.fromMap(Map<String, dynamic> map) {
    return CaseChildProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dob: map['dob'] ?? '',
      school: map['school'] ?? '',
      grade: map['grade'] ?? '',
      specialNeeds: map['specialNeeds'] ?? '',
      dailyRoutine: map['dailyRoutine'] ?? '',
      currentLivingArrangement: map['currentLivingArrangement'] ?? 'Pending',
      distanceBetweenHomes: (map['distanceBetweenHomes'] ?? 0.0).toDouble(),
      parentAWorkHours: map['parentAWorkHours'] ?? '',
      parentBWorkHours: map['parentBWorkHours'] ?? '',
      parentingPlan: map['parentingPlan'],
    );
  }
}
