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
        try {
          attachments = (map['attachments'] as List)
              .whereType<Map>()
              .map((attachment) => FileAttachment.fromMap(attachment as Map<dynamic, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error parsing poll attachments: $e');
          attachments = null;
        }
      }

      // Parse options safely
      final List<PollOption> options = [];
      for (var option in optionsList) {
        try {
          if (option is Map) {
            options.add(PollOption.fromMap(option));
          } else {
            options.add(PollOption(id: '0', text: 'Option'));
          }
        } catch (e) {
          debugPrint('Error parsing poll option: $e');
          options.add(PollOption(id: '0', text: 'Option'));
        }
      }

      return Poll(
        question: question,
        options: options,
        expiresAt: expiresAt,
        allowMultipleChoices: allowMultiple,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        attachments: attachments,
      );
    } catch (e) {
      debugPrint('Error parsing poll data: $e');
      // Return a default poll instead of rethrowing to prevent app crashes
      return Poll(
        question: 'Error loading poll',
        options: [PollOption(id: '0', text: 'Option')],
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
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
      List<String> votedBy = [];
      if (map['votedBy'] is Map) {
        try {
          votedBy = (map['votedBy'] as Map<dynamic, dynamic>)
              .keys
              .map((k) => k.toString())
              .toList();
        } catch (e) {
          debugPrint('Error parsing votedBy: $e');
          votedBy = [];
        }
      }

      return PollOption(
        id: id,
        text: text,
        votedBy: votedBy,
      );
    } catch (e) {
      debugPrint('Error parsing poll option data: $e');
      // Return a default option instead of rethrowing to prevent app crashes
      return PollOption(
        id: '0',
        text: 'Option',
        votedBy: [],
      );
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
    try {
      return FileAttachment(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: map['name']?.toString() ?? 'File',
        url: map['url']?.toString() ?? '',
        type: map['type']?.toString() ?? 'unknown',
        size: map['size'] is int ? map['size'] as int : 0,
      );
    } catch (e) {
      debugPrint('Error parsing file attachment: $e');
      // Return a default attachment instead of throwing to prevent app crashes
      return FileAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Error loading file',
        url: '',
        type: 'unknown',
        size: 0,
      );
    }
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
    try {
      if (data != null) {
        // Handle case where id and data are passed separately
        String id = '';
        try {
          id = source.toString();
        } catch (e) {
          debugPrint('Error parsing id: $e');
          id = DateTime.now().millisecondsSinceEpoch.toString();
        }

        return CommunityNotice(
          id: id,
          title: data['title'] != null ? data['title'].toString() : '',
          content: data['content'] != null ? data['content'].toString() : '',
          authorId: data['authorId'] != null ? data['authorId'].toString() : '',
          authorName: data['authorName'] != null ? data['authorName'].toString() : '',
          authorAvatar: data['authorAvatar'] != null ? data['authorAvatar'].toString() : null,
          imageUrls: data['imageUrls'] != null && data['imageUrls'] is List
              ? (data['imageUrls'] as List).map((url) => url.toString()).toList()
              : data['imageUrl'] != null
                  ? [data['imageUrl'].toString()]
                  : null,
          videoUrl: data['videoUrl'] != null ? data['videoUrl'].toString() : null,
          poll: data['poll'] != null && data['poll'] is Map
              ? Poll.fromMap(data['poll'] as Map<dynamic, dynamic>)
              : null,
          attachments: data['attachments'] != null && data['attachments'] is List
              ? (data['attachments'] as List)
                  .whereType<Map>()
                  .map((attachment) => FileAttachment.fromMap(attachment))
                  .toList()
              : null,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(data['createdAt'] is int ? data['createdAt'] : 0),
          updatedAt:
              DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] is int ? data['updatedAt'] : 0),
          likedBy:
              data['likedBy'] is List
                  ? (data['likedBy'] as List).map((e) => e.toString()).toList()
                  : [],
          comments: data['comments'] is List
                  ? (data['comments'] as List)
                      .whereType<Map>()
                      .map((comment) => Comment.fromMap(comment))
                      .toList()
                  : [],
        );
      }

      // Handle case where everything is in a single map
      if (source is! Map) {
        throw FormatException('Source is not a Map: $source');
      }

      final map = source;

      return CommunityNotice(
        id: map['id'] != null ? map['id'].toString() : DateTime.now().millisecondsSinceEpoch.toString(),
        title: map['title'] != null ? map['title'].toString() : '',
        content: map['content'] != null ? map['content'].toString() : '',
        authorId: map['authorId'] != null ? map['authorId'].toString() : '',
        authorName: map['authorName'] != null ? map['authorName'].toString() : '',
        authorAvatar: map['authorAvatar'] != null ? map['authorAvatar'].toString() : null,
        imageUrls: map['imageUrls'] != null && map['imageUrls'] is List
            ? (map['imageUrls'] as List).map((url) => url.toString()).toList()
            : map['imageUrl'] != null
                ? [map['imageUrl'].toString()]
                : null,
        videoUrl: map['videoUrl'] != null ? map['videoUrl'].toString() : null,
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
        attachments: map['attachments'] != null && map['attachments'] is List
            ? (map['attachments'] as List)
                .whereType<Map>()
                .map((attachment) => FileAttachment.fromMap(attachment))
                .toList()
            : null,
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] is int ? map['createdAt'] : 0),
        updatedAt: map['updatedAt'] is Timestamp
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] is int ? map['updatedAt'] : 0),
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
    } catch (e) {
      debugPrint('Error in CommunityNotice.fromMap: $e');
      // Return a fallback notice to prevent app crashes
      return CommunityNotice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Error loading notice',
        content: 'There was an error loading this notice. Please try again later.',
        authorId: '',
        authorName: 'System',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likedBy: [],
        comments: [],
      );
    }
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

  // Get total comments count including replies
  int get commentsCount {
    int totalCount = comments.length;
    for (var comment in comments) {
      totalCount += comment.replies.length;
    }
    return totalCount;
  }

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
  final List<String> likedBy;
  final List<Comment> replies;
  final String? parentId;
  final String? replyToId; // ID of the specific comment being replied to (might be a reply itself)

  Comment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.createdAt,
    this.likedBy = const [],
    this.replies = const [],
    this.parentId,
    this.replyToId,
  }) {
    // Constructor
  }

  factory Comment.fromMap(Map<dynamic, dynamic> map) {
    try {
      // Parse likes
      List<String> likedBy = [];
      if (map['likes'] is Map) {
        likedBy = (map['likes'] as Map<dynamic, dynamic>)
            .keys
            .map((k) => k.toString())
            .toList();
      }

      // Parse replies
      List<Comment> replies = [];
      if (map['replies'] is Map) {

        replies = (map['replies'] as Map<dynamic, dynamic>).entries.map((entry) {
          if (entry.value is! Map) return null;
          try {
            // Get the original data
            final replyData = entry.value as Map<dynamic, dynamic>;

            // Check if this is a reply to another reply (has replyToId)
            final String? replyToId = replyData['replyToId']?.toString();

            return Comment.fromMap({
              ...replyData,
              'id': entry.key.toString(),
              'parentId': map['id']?.toString() ?? '',
              'replyToId': replyToId,
            });
          } catch (e) {
            // Return null on error to filter out invalid replies
            return null;
          }
        }).whereType<Comment>().toList();
      }

      return Comment(
        id: map['id'] != null ? map['id'].toString() : DateTime.now().millisecondsSinceEpoch.toString(),
        content: map['content'] != null ? map['content'].toString() : '',
        authorId: map['authorId'] != null ? map['authorId'].toString() : '',
        authorName: map['authorName'] != null ? map['authorName'].toString() : '',
        authorAvatar: map['authorAvatar'] != null ? map['authorAvatar'].toString() : null,
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] is int ? map['createdAt'] : 0),
        likedBy: likedBy,
        replies: replies,
        parentId: map['parentId'] != null ? map['parentId'].toString() : null,
        replyToId: map['replyToId'] != null ? map['replyToId'].toString() : null,
      );
    } catch (e) {
      // Return a fallback comment to prevent app crashes
      return Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: 'Error loading comment',
        authorId: '',
        authorName: 'System',
        createdAt: DateTime.now(),
        likedBy: [],
        replies: [],
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'createdAt': createdAt,
      'parentId': parentId,
      'replyToId': replyToId,
      // Convert likes to map format for Firebase
      'likes': likedBy.isEmpty ? null : {for (var userId in likedBy) userId: true},
      // Convert replies to map format for Firebase
      'replies': replies.isEmpty ? null : {for (var reply in replies) reply.id: reply.toMap()},
    };
  }

  bool isLikedBy(String userId) => likedBy.contains(userId);

  int get likesCount => likedBy.length;
  int get repliesCount => replies.length;

  Comment copyWith({
    String? id,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    DateTime? createdAt,
    List<String>? likedBy,
    List<Comment>? replies,
    String? parentId,
    String? replyToId,
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      createdAt: createdAt ?? this.createdAt,
      likedBy: likedBy ?? this.likedBy,
      replies: replies ?? this.replies,
      parentId: parentId ?? this.parentId,
      replyToId: replyToId ?? this.replyToId,
    );
  }
}
