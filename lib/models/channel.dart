import 'package:cloud_firestore/cloud_firestore.dart';

class Channel {
  final String id;
  final String ownerId;
  final String name;
  final String handle; // Unique @handle
  final String description;
  final String? profileImageUrl;
  final List<String> externalLinks; // e.g. YouTube, Instagram
  final int followersCount;
  final DateTime createdAt;
  final bool isHidden;

  Channel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.handle,
    required this.description,
    this.profileImageUrl,
    this.externalLinks = const [],
    this.followersCount = 0,
    required this.createdAt,
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'handle': handle,
      'description': description,
      'profileImageUrl': profileImageUrl,
      'externalLinks': externalLinks,
      'followersCount': followersCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'isHidden': isHidden,
    };
  }

  factory Channel.fromMap(Map<String, dynamic> map, String id) {
    return Channel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      handle: map['handle'] ?? '',
      description: map['description'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      externalLinks: List<String>.from(map['externalLinks'] ?? []),
      followersCount: map['followersCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isHidden: map['isHidden'] ?? false,
    );
  }
}

class ChannelPost {
  final String id;
  final String channelId;
  final String authorId; // Owner of the channel
  final String authorName; // Channel name
  final String? authorImage; // Channel image
  final String content;
  final String? mediaUrl; // Image/Video
  final String? thumbnailUrl;
  final int likesCount;
  final List<String> likedBy;
  final int commentsCount;
  final int repostsCount;
  final List<String> repostedBy;
  final bool isRepost;
  final String? originalPostId;
  final String? originalAuthorName;
  final String? repostThoughts;
  final DateTime createdAt;

  ChannelPost({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    this.authorImage,
    required this.content,
    this.mediaUrl,
    this.thumbnailUrl,
    this.likesCount = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    this.repostsCount = 0,
    this.repostedBy = const [],
    this.isRepost = false,
    this.originalPostId,
    this.originalAuthorName,
    this.repostThoughts,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'content': content,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'likesCount': likesCount,
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'repostsCount': repostsCount,
      'repostedBy': repostedBy,
      'isRepost': isRepost,
      'originalPostId': originalPostId,
      'originalAuthorName': originalAuthorName,
      'repostThoughts': repostThoughts,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChannelPost.fromMap(Map<String, dynamic> map, String id) {
    return ChannelPost(
      id: id,
      channelId: map['channelId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorImage: map['authorImage'],
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      likesCount: map['likesCount'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentsCount: map['commentsCount'] ?? 0,
      repostsCount: map['repostsCount'] ?? 0,
      repostedBy: List<String>.from(map['repostedBy'] ?? []),
      isRepost: map['isRepost'] ?? false,
      originalPostId: map['originalPostId'],
      originalAuthorName: map['originalAuthorName'],
      repostThoughts: map['repostThoughts'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChannelComment {
  final String id;
  final String postId;
  final String userId;
  final String userName; // To avoid extra fetches
  final String content;
  final DateTime createdAt;

  ChannelComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChannelComment.fromMap(Map<String, dynamic> map, String id) {
    return ChannelComment(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

