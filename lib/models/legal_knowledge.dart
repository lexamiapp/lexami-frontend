
class LegalStatute {
  final String id;
  final String actName;
  final String section;
  final String description;
  final List<String> keywords;

  LegalStatute({
    required this.id,
    required this.actName,
    required this.section,
    required this.description,
    required this.keywords,
  });

  Map<String, dynamic> toMap() {
    return {
      'actName': actName,
      'section': section,
      'description': description,
      'keywords': keywords,
    };
  }

  factory LegalStatute.fromMap(Map<String, dynamic> map, String id) {
    return LegalStatute(
      id: id,
      actName: map['actName'] ?? '',
      section: map['section'] ?? '',
      description: map['description'] ?? '',
      keywords: List<String>.from(map['keywords'] ?? []),
    );
  }
}

class LandmarkJudgment {
  final String id;
  final String caseName;
  final String court;
  final int year;
  final String summary;
  final String ruling;
  final List<String> applicableSections;

  LandmarkJudgment({
    required this.id,
    required this.caseName,
    required this.court,
    required this.year,
    required this.summary,
    required this.ruling,
    required this.applicableSections,
  });

  Map<String, dynamic> toMap() {
    return {
      'caseName': caseName,
      'court': court,
      'year': year,
      'summary': summary,
      'ruling': ruling,
      'applicableSections': applicableSections,
    };
  }

  factory LandmarkJudgment.fromMap(Map<String, dynamic> map, String id) {
    return LandmarkJudgment(
      id: id,
      caseName: map['caseName'] ?? '',
      court: map['court'] ?? '',
      year: map['year'] ?? 0,
      summary: map['summary'] ?? '',
      ruling: map['ruling'] ?? '',
      applicableSections: List<String>.from(map['applicableSections'] ?? []),
    );
  }
}
