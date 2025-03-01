class CommunityNotice {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final String communityId;

  CommunityNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.communityId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likes': likes,
      'comments': comments,
      'communityId': communityId,
    };
  }

  factory CommunityNotice.fromMap(String id, Map<dynamic, dynamic> map) {
    return CommunityNotice(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      communityId: map['communityId'] ?? '',
    );
  }
}
