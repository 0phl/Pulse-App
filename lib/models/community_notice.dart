import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityNotice {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> likedBy;
  final List<Comment> comments;

  CommunityNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.likedBy,
    required this.comments,
  });

  factory CommunityNotice.fromMap(dynamic source,
      [Map<dynamic, dynamic>? data]) {
    if (data != null) {
      // Handle case where id and data are passed separately
      return CommunityNotice(
        id: source as String,
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        authorId: data['authorId'] as String? ?? '',
        authorName: data['authorName'] as String? ?? '',
        authorAvatar: data['authorAvatar'] as String?,
        imageUrl: data['imageUrl'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int? ?? 0),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] as int? ?? 0),
        likedBy:
            (data['likedBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
        comments: (data['comments'] as List?)
                ?.map((comment) =>
                    Comment.fromMap(comment as Map<dynamic, dynamic>))
                .toList() ??
            [],
      );
    }

    // Handle case where everything is in a single map
    final map = source as Map<String, dynamic>;
    return CommunityNotice(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorAvatar: map['authorAvatar'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int? ?? 0),
      likedBy: (map['likes'] is Map
              ? (map['likes'] as Map<dynamic, dynamic>).keys.map((k) => k.toString()).toList()
              : []) ??
          [],
      comments: (map['comments'] is Map
              ? (map['comments'] as Map<dynamic, dynamic>).entries.map((entry) {
                  if (entry.value is! Map) return null;
                  return Comment.fromMap({
                    ...entry.value as Map<dynamic, dynamic>,
                    'id': entry.key.toString(),
                  });
                }).whereType<Comment>().toList()
              : []) ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'likedBy': likedBy,
      'comments': comments.map((comment) => comment.toMap()).toList(),
    };
  }

  bool isLikedBy(String userId) => likedBy.contains(userId);

  int get likesCount => likedBy.length;
  int get commentsCount => comments.length;

  CommunityNotice copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? likedBy,
    List<Comment>? comments,
  }) {
    return CommunityNotice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likedBy: likedBy ?? this.likedBy,
      comments: comments ?? this.comments,
    );
  }
}

class Comment {
  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<dynamic, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      content: map['content'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorAvatar: map['authorAvatar'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'createdAt': createdAt,
    };
  }
}
