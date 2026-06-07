class Advisor {
  final String id;
  final String name;
  final String category; // 'Advocate', 'Counselor', 'Retired Judge', etc.
  final String specialization; // Used as Primary Practice Area
  final double experience; // in years
  final int casesWon; // Number of cases won (New Field)
  final double successRate; // percentage
  final double pricePerMin; // For calling/chatting
  final double rating;
  final String country;
  final String state;
  final String district;
  final String city;
  final String officeAddress;
  final String? profileImageUrl;
  final List<String> languagesSpoken;
  final bool isOnline;
  final double ratingScore;

  // Professional Credentials (may be optional for some categories)
  final String? barRegistrationNumber; // For Advocates
  final String? stateBarCouncil;        // For Advocates
  final int? enrollmentYear;           // For Advocates
  
  final String? certificationNumber;   // For Counselors
  final String? issuingAuthority;     // For Counselors
  
  final String? retirementCourt;       // For Retired Judge/Lawyer
  final int? retirementYear;           // For Retired Judge/Lawyer
  
  // Verification & Admin
  final String verificationStatus; // 'pending', 'under_review', 'verified', 'rejected'
  final bool isVerified;
  final DateTime? appliedAt;
  final String? reviewedBy; // Admin ID
  final String? reviewerName; // Admin Name
  final DateTime? reviewedAt;

  Advisor({
    required this.id,
    required this.name,
    required this.category,
    required this.specialization,
    required this.experience,
    required this.successRate,
    this.casesWon = 0,
    required this.pricePerMin,
    required this.rating,
    required this.country,
    required this.state,
    required this.district,
    required this.city,
    required this.officeAddress,
    this.profileImageUrl,
    required this.languagesSpoken,
    this.isOnline = false,
    this.ratingScore = 0.0,
    this.barRegistrationNumber,
    this.stateBarCouncil,
    this.enrollmentYear,
    this.certificationNumber,
    this.issuingAuthority,
    this.retirementCourt,
    this.retirementYear,
    this.verificationStatus = 'pending',
    this.isVerified = false,
    this.appliedAt,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'specialization': specialization,
      'experience': experience,
      'successRate': successRate,
      'casesWon': casesWon,
      'pricePerMin': pricePerMin,
      'rating': rating,
      'country': country,
      'state': state,
      'district': district,
      'city': city,
      'officeAddress': officeAddress,
      'profileImageUrl': profileImageUrl,
      'languagesSpoken': languagesSpoken,
      'isOnline': isOnline,
      'ratingScore': ratingScore,
      'barRegistrationNumber': barRegistrationNumber,
      'stateBarCouncil': stateBarCouncil,
      'enrollmentYear': enrollmentYear,
      'certificationNumber': certificationNumber,
      'issuingAuthority': issuingAuthority,
      'retirementCourt': retirementCourt,
      'retirementYear': retirementYear,
      'verificationStatus': verificationStatus,
      'isVerified': isVerified,
      'appliedAt': appliedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewerName': reviewerName,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }

  factory Advisor.fromMap(Map<String, dynamic> map, String id) {
    return Advisor(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'Advocate',
      specialization: map['specialization'] ?? '',
      experience: (map['experience'] as num?)?.toDouble() ?? 0.0,
      successRate: (map['successRate'] as num?)?.toDouble() ?? 0.0,
      casesWon: map['casesWon'] ?? 0,
      pricePerMin: (map['pricePerMin'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      district: map['district'] ?? '',
      city: map['city'] ?? '',
      officeAddress: map['officeAddress'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      languagesSpoken: List<String>.from(map['languagesSpoken'] ?? []),
      isOnline: map['isOnline'] ?? false,
      ratingScore: (map['ratingScore'] as num?)?.toDouble() ?? 0.0,
      barRegistrationNumber: map['barRegistrationNumber'],
      stateBarCouncil: map['stateBarCouncil'],
      enrollmentYear: map['enrollmentYear'],
      certificationNumber: map['certificationNumber'],
      issuingAuthority: map['issuingAuthority'],
      retirementCourt: map['retirementCourt'],
      retirementYear: map['retirementYear'],
      verificationStatus: map['verificationStatus'] ?? 'pending',
      isVerified: map['isVerified'] ?? false,
      appliedAt: map['appliedAt'] != null ? DateTime.tryParse(map['appliedAt']) : null,
      reviewedBy: map['reviewedBy'],
      reviewerName: map['reviewerName'],
      reviewedAt: map['reviewedAt'] != null ? DateTime.tryParse(map['reviewedAt']) : null,
    );
  }
}
