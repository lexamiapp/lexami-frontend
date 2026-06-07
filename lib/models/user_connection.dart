import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { pending, accepted, ignored }

class UserConnection {
  final String id;
  final String senderId;
  final String receiverId;
  final ConnectionStatus status;
  final DateTime createdAt;

  UserConnection({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserConnection.fromMap(Map<String, dynamic> map, String id) {
    return UserConnection(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => ConnectionStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
