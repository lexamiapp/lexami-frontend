import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPost {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isApproved;

  BlogPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isApproved = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isApproved': isApproved,
    };
  }

  factory BlogPost.fromMap(Map<String, dynamic> map, String id) {
    return BlogPost(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isApproved: map['isApproved'] ?? false,
    );
  }
}
