import 'package:cloud_firestore/cloud_firestore.dart';

class ForumQuestion {
  final String id;
  final String userId;
  final String authorName;
  final String title;
  final String description;
  final List<String> tags;
  final int answersCount;
  final DateTime createdAt;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? mediaType; // 'image' or 'video'
  final int likesCount;
  final List<String> likedBy;
  final int repostsCount;
  final List<String> repostedBy;
  final int commentsCount;
  final bool isRepost;
  final String? originalAuthorName;
  final String? originalPostId;
  final String? repostThoughts;

  ForumQuestion({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.title,
    required this.description,
    required this.tags,
    this.answersCount = 0,
    required this.createdAt,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.likesCount = 0,
    this.likedBy = const [],
    this.repostsCount = 0,
    this.repostedBy = const [],
    this.commentsCount = 0,
    this.isRepost = false,
    this.originalAuthorName,
    this.originalPostId,
    this.repostThoughts,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'authorName': authorName,
      'title': title,
      'description': description,
      'tags': tags,
      'answersCount': answersCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'mediaType': mediaType,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'repostsCount': repostsCount,
      'repostedBy': repostedBy,
      'commentsCount': commentsCount,
      'isRepost': isRepost,
      'originalAuthorName': originalAuthorName,
      'originalPostId': originalPostId,
      'repostThoughts': repostThoughts,
    };
  }

  factory ForumQuestion.fromMap(Map<String, dynamic> map, String id) {
    return ForumQuestion(
      id: id,
      userId: map['userId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      answersCount: map['answersCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mediaUrl: map['mediaUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      mediaType: map['mediaType'],
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      repostsCount: map['repostsCount'] ?? 0,
      repostedBy: List<String>.from(map['repostedBy'] ?? []),
      commentsCount: map['commentsCount'] ?? 0,
      isRepost: map['isRepost'] ?? false,
      originalAuthorName: map['originalAuthorName'],
      originalPostId: map['originalPostId'],
      repostThoughts: map['repostThoughts'],
    );
  }
}
