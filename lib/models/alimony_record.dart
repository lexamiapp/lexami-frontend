import 'package:cloud_firestore/cloud_firestore.dart';

class AlimonyRecord {
  final String id;
  final String userId;
  final String type; // 'paid' or 'received'
  final double amount;
  final String category; // 'Monthly', 'Lump Sum', 'Maintenance', etc.
  final DateTime date;
  final String? note;

  AlimonyRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }

  factory AlimonyRecord.fromMap(String id, Map<String, dynamic> map) {
    return AlimonyRecord(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'paid',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'],
    );
  }
}
