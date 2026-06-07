import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisHistory {
  final String id;
  final String userId;
  final String caseType;
  final String summary;
  final String result;
  final DateTime createdAt;
  final Map<String, dynamic>? formData; // Optional form data for drafting vault

  AnalysisHistory({
    required this.id,
    required this.userId,
    required this.caseType,
    required this.summary,
    required this.result,
    required this.createdAt,
    this.formData,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caseType': caseType,
      'summary': summary,
      'result': result,
      'createdAt': Timestamp.fromDate(createdAt),
      if (formData != null) 'formData': formData,
    };
  }

  factory AnalysisHistory.fromMap(Map<String, dynamic> map, String id) {
    return AnalysisHistory(
      id: id,
      userId: map['userId'] ?? '',
      caseType: map['caseType'] ?? '',
      summary: map['summary'] ?? '',
      result: map['result'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      formData: map['formData'] as Map<String, dynamic>?,
    );
  }
}
