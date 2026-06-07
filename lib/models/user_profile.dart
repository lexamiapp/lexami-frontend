class UserProfile {
  // 1. Identity
  final String uid;
  final String fullName;
  final String email;
  final String? photoUrl;
  final String mobile;
  final String gender;
  final DateTime? dob;
  
  // 2. Core Family Relations
  final String fatherName;
  final String motherName;
  final String maritalStatus; // 'Single', 'Married', 'Divorced', 'Widowed', 'Separated'
  final String? spouseName;

  // 3. Role in Family
  final String roleInFamily; // 'Son', 'Daughter', 'Spouse', 'Parent', 'Head of Family', 'Other'

  // 4. Address
  final String currentAddress;
  final String city;
  final String state;
  final String country;

  // 5. Extended Legal & Financial Info (Optional)
  final String? occupation;
  final double? annualIncome;
  final DateTime? marriageDate;
  final int childrenCount;
  final String? permanentAddress;

  // 6. Dispute Context
  final String disputeNature; // 'Property', 'Marriage', 'Inheritance', 'Custody', 'Financial', 'Other'
  final String relationshipWithOtherParty;

  // 7. Consent & Metadata
  final bool consentTrue;
  final bool isProfileComplete;
  final bool isAdvisor; // Start with false for regular users
  final bool isVerifiedAdvisor; // Permission for blogs
  final bool isProfileLive; // Privacy toggle
  final String? communityAlias; // Name to show in community
  final bool useAliasInCommunity; // Toggle for alias
  final List<String> followedChannels;
  final List<String> followedUsers;
  final double walletBalance; // Default to 0.0
  final bool isAdmin; // Admin permission

  String get displayName => (useAliasInCommunity && communityAlias != null && communityAlias!.isNotEmpty) 
      ? communityAlias! 
      : fullName;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.photoUrl,
    required this.mobile,
    required this.gender,
    this.dob,
    required this.fatherName,
    required this.motherName,
    required this.maritalStatus,
    this.spouseName,
    required this.roleInFamily,
    required this.currentAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.disputeNature,
    required this.relationshipWithOtherParty,
    required this.consentTrue,
    this.isProfileComplete = false,
    this.isAdvisor = false,
    this.isVerifiedAdvisor = false,
    this.isProfileLive = true,
    this.communityAlias,
    this.useAliasInCommunity = false,
    this.followedChannels = const [],
    this.followedUsers = const [],
    this.walletBalance = 0.0,
    this.occupation,
    this.annualIncome,
    this.marriageDate,
    this.childrenCount = 0,
    this.permanentAddress,
    this.isAdmin = false,
  });

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? photoUrl,
    String? mobile,
    String? gender,
    DateTime? dob,
    String? fatherName,
    String? motherName,
    String? maritalStatus,
    String? spouseName,
    String? roleInFamily,
    String? currentAddress,
    String? city,
    String? state,
    String? country,
    String? disputeNature,
    String? relationshipWithOtherParty,
    bool? consentTrue,
    bool? isProfileComplete,
    bool? isAdvisor,
    bool? isVerifiedAdvisor,
    bool? isProfileLive,
    String? communityAlias,
    bool? useAliasInCommunity,
    List<String>? followedChannels,
    List<String>? followedUsers,
    double? walletBalance,
    String? occupation,
    double? annualIncome,
    DateTime? marriageDate,
    int? childrenCount,
    String? permanentAddress,
    bool? isAdmin,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      mobile: mobile ?? this.mobile,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      spouseName: spouseName ?? this.spouseName,
      roleInFamily: roleInFamily ?? this.roleInFamily,
      currentAddress: currentAddress ?? this.currentAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      disputeNature: disputeNature ?? this.disputeNature,
      relationshipWithOtherParty: relationshipWithOtherParty ?? this.relationshipWithOtherParty,
      consentTrue: consentTrue ?? this.consentTrue,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isAdvisor: isAdvisor ?? this.isAdvisor,
      isVerifiedAdvisor: isVerifiedAdvisor ?? this.isVerifiedAdvisor,
      isProfileLive: isProfileLive ?? this.isProfileLive,
      communityAlias: communityAlias ?? this.communityAlias,
      useAliasInCommunity: useAliasInCommunity ?? this.useAliasInCommunity,
      followedChannels: followedChannels ?? this.followedChannels,
      followedUsers: followedUsers ?? this.followedUsers,
      walletBalance: walletBalance ?? this.walletBalance,
      occupation: occupation ?? this.occupation,
      annualIncome: annualIncome ?? this.annualIncome,
      marriageDate: marriageDate ?? this.marriageDate,
      childrenCount: childrenCount ?? this.childrenCount,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'photoUrl': photoUrl,
      'mobile': mobile,
      'gender': gender,
      'dob': dob?.toIso8601String(),
      'fatherName': fatherName,
      'motherName': motherName,
      'maritalStatus': maritalStatus,
      'spouseName': spouseName,
      'roleInFamily': roleInFamily,
      'currentAddress': currentAddress,
      'city': city,
      'state': state,
      'country': country,
      'disputeNature': disputeNature,
      'relationshipWithOtherParty': relationshipWithOtherParty,
      'consentTrue': consentTrue,
      'isProfileComplete': isProfileComplete,
      'isAdvisor': isAdvisor,
      'isVerifiedAdvisor': isVerifiedAdvisor,
      'isProfileLive': isProfileLive,
      'communityAlias': communityAlias,
      'useAliasInCommunity': useAliasInCommunity,
      'followedChannels': followedChannels,
      'followedUsers': followedUsers,
      'walletBalance': walletBalance,
      'occupation': occupation,
      'annualIncome': annualIncome,
      'marriageDate': marriageDate?.toIso8601String(),
      'childrenCount': childrenCount,
      'permanentAddress': permanentAddress,
      'isAdmin': isAdmin,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      uid: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      mobile: map['mobile'] ?? '',
      gender: map['gender'] ?? '',
      dob: map['dob'] != null ? DateTime.tryParse(map['dob']) : null,
      fatherName: map['fatherName'] ?? '',
      motherName: map['motherName'] ?? '',
      maritalStatus: map['maritalStatus'] ?? 'Single',
      spouseName: map['spouseName'],
      roleInFamily: map['roleInFamily'] ?? 'Other',
      currentAddress: map['currentAddress'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      disputeNature: map['disputeNature'] ?? 'Other',
      relationshipWithOtherParty: map['relationshipWithOtherParty'] ?? '',
      consentTrue: map['consentTrue'] ?? false,
      isProfileComplete: map['isProfileComplete'] ?? false,
      isAdvisor: map['isAdvisor'] ?? map['isLawyer'] ?? false,
      isVerifiedAdvisor: map['isVerifiedAdvisor'] ?? map['isVerifiedLawyer'] ?? false,
      isProfileLive: map['isProfileLive'] ?? true,
      communityAlias: map['communityAlias'] ?? map['pseudonym'],
      useAliasInCommunity: map['useAliasInCommunity'] ?? false,
      followedChannels: List<String>.from(map['followedChannels'] ?? []),
      followedUsers: List<String>.from(map['followedUsers'] ?? []),
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      occupation: map['occupation'],
      annualIncome: (map['annualIncome'] ?? 0.0).toDouble(),
      marriageDate: map['marriageDate'] != null ? DateTime.tryParse(map['marriageDate']) : null,
      childrenCount: map['childrenCount'] ?? 0,
      permanentAddress: map['permanentAddress'],
      isAdmin: map['isAdmin'] ?? false,
    );
  }
}
