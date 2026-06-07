import 'package:cloud_firestore/cloud_firestore.dart';

class ForumComment {
  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final List<String> likedBy;
  final bool isAnonymous;

  ForumComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.likedBy = const [],
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'likedBy': likedBy,
      'isAnonymous': isAnonymous,
    };
  }

  factory ForumComment.fromMap(Map<String, dynamic> map, String id) {
    return ForumComment(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }
}
