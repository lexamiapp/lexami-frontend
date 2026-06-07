class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? type; // 'approval', 'message', 'system'

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      isRead: map['isRead'] ?? false,
      type: map['type'],
    );
  }
}
