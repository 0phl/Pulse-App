import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Poll {
  final String question;
  final List<PollOption> options;
  final DateTime expiresAt;
  final bool allowMultipleChoices;
  final List<String>? imageUrls;
  final String? videoUrl;
  final List<FileAttachment>? attachments;

  Poll({
    required this.question,
    required this.options,
    required this.expiresAt,
    this.allowMultipleChoices = false,
    this.imageUrls,
    this.videoUrl,
    this.attachments,
  });

  factory Poll.fromMap(Map<dynamic, dynamic> map) {
    try {
      // Ensure question is a string
      final String question = map['question']?.toString() ?? 'Poll Question';

      // Ensure options is a list
      final List<dynamic> optionsList = map['options'] is List ? map['options'] as List<dynamic> : [];

      // Ensure expiresAt is a valid DateTime
      final DateTime expiresAt = map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : map['expiresAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
              : DateTime.now().add(const Duration(days: 7));

      // Ensure allowMultipleChoices is a boolean
      final bool allowMultiple = map['allowMultipleChoices'] == true;

      // Parse imageUrls if available
      List<String>? imageUrls;
      if (map['imageUrls'] is List) {
        imageUrls = (map['imageUrls'] as List).map((url) => url.toString()).toList();
      }

      // Parse videoUrl if available
      final String? videoUrl = map['videoUrl']?.toString();

      // Parse attachments if available
      List<FileAttachment>? attachments;
      if (map['attachments'] is List) {
        attachments = (map['attachments'] as List)
            .map((attachment) => FileAttachment.fromMap(attachment as Map<dynamic, dynamic>))
            .toList();
      }

      return Poll(
        question: question,
        options: optionsList
            .map((option) => PollOption.fromMap(option is Map ? option : {'id': '0', 'text': 'Option'}))
            .toList(),
        expiresAt: expiresAt,
        allowMultipleChoices: allowMultiple,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        attachments: attachments,
      );
    } catch (e) {
      debugPrint('Error parsing poll data: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options.map((option) => option.toMap()).toList(),
      'expiresAt': expiresAt,
      'allowMultipleChoices': allowMultipleChoices,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'attachments': attachments?.map((attachment) => attachment.toMap()).toList(),
    };
  }
}

class PollOption {
  final String id;
  final String text;
  final List<String> votedBy;

  PollOption({
    required this.id,
    required this.text,
    this.votedBy = const [],
  });

  factory PollOption.fromMap(Map<dynamic, dynamic> map) {
    try {
      // Ensure id is a string
      final String id = map['id']?.toString() ?? '0';

      // Ensure text is a string
      final String text = map['text']?.toString() ?? 'Option';

      // Ensure votedBy is a list
      final List<String> votedBy = map['votedBy'] is Map
          ? (map['votedBy'] as Map<dynamic, dynamic>)
              .keys
              .map((k) => k.toString())
              .toList()
          : [];

      return PollOption(
        id: id,
        text: text,
        votedBy: votedBy,
      );
    } catch (e) {
      debugPrint('Error parsing poll option data: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'votedBy': votedBy.isEmpty ? null : {for (var v in votedBy) v: true},
    };
  }

  int get voteCount => votedBy.length;
}

class FileAttachment {
  final String id;
  final String name;
  final String url;
  final String type;
  final int size; // in bytes

  FileAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.size,
  });

  factory FileAttachment.fromMap(Map<dynamic, dynamic> map) {
    return FileAttachment(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      type: map['type'] as String,
      size: map['size'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'size': size,
    };
  }
}

class CommunityNotice {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final List<String>? imageUrls; // Changed from single imageUrl to list
  final String? videoUrl;
  final Poll? poll;
  final List<FileAttachment>? attachments;
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
    this.imageUrls,
    this.videoUrl,
    this.poll,
    this.attachments,
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
        imageUrls: data['imageUrls'] != null
            ? (data['imageUrls'] as List).map((url) => url.toString()).toList()
            : data['imageUrl'] != null
                ? [data['imageUrl'] as String]
                : null,
        videoUrl: data['videoUrl'] as String?,
        poll: data['poll'] != null ? Poll.fromMap(data['poll'] as Map<dynamic, dynamic>) : null,
        attachments: data['attachments'] != null
            ? (data['attachments'] as List)
                .map((attachment) => FileAttachment.fromMap(attachment as Map<dynamic, dynamic>))
                .toList()
            : null,
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
      imageUrls: map['imageUrls'] != null
          ? (map['imageUrls'] as List).map((url) => url.toString()).toList()
          : map['imageUrl'] != null
              ? [map['imageUrl'] as String]
              : null,
      videoUrl: map['videoUrl'] as String?,
      poll: map['poll'] != null ? (() {
          try {
            if (map['poll'] is Map) {
              return Poll.fromMap(map['poll'] as Map<dynamic, dynamic>);
            } else {
              return null;
            }
          } catch (e) {
            debugPrint('Error parsing poll data: $e');
            return null;
          }
        })() : null,
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((attachment) => FileAttachment.fromMap(attachment as Map<dynamic, dynamic>))
              .toList()
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? 0),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int? ?? 0),
      likedBy: map['likes'] is Map
              ? (map['likes'] as Map<dynamic, dynamic>).keys.map((k) => k.toString()).toList()
              : [],
      comments: map['comments'] is Map
              ? (map['comments'] as Map<dynamic, dynamic>).entries.map((entry) {
                  if (entry.value is! Map) return null;
                  return Comment.fromMap({
                    ...entry.value as Map<dynamic, dynamic>,
                    'id': entry.key.toString(),
                  });
                }).whereType<Comment>().toList()
              : [],
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
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'poll': poll?.toMap(),
      'attachments': attachments?.map((attachment) => attachment.toMap()).toList(),
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
    List<String>? imageUrls,
    String? videoUrl,
    Poll? poll,
    List<FileAttachment>? attachments,
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
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      poll: poll ?? this.poll,
      attachments: attachments ?? this.attachments,
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
