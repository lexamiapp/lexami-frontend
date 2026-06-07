enum TransactionType { credit, debit }
enum TransactionCategory { wallet_recharge, call_payment, consultation_fee, referral_bonus, withdrawal }

class AppTransaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime timestamp;
  final String? relatedId; // e.g., callSessionId, advisorId
  final String description;

  AppTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.timestamp,
    this.relatedId,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'relatedId': relatedId,
      'description': description,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map, String id) {
    return AppTransaction(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere((e) => e.name == map['type'], orElse: () => TransactionType.debit),
      category: TransactionCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => TransactionCategory.call_payment),
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      relatedId: map['relatedId'],
      description: map['description'] ?? '',
    );
  }
}
