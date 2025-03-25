import 'package:firebase_database/firebase_database.dart';
import '../models/community_notice.dart';

class CommunityNoticeService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get all notices for a community
  Stream<List<CommunityNotice>> getNotices(String communityId) {
    return _database
        .child('community_notices')
        .orderByChild('communityId')
        .equalTo(communityId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final notices = data.entries.map((entry) {
        final originalData = entry.value as Map<dynamic, dynamic>;
        final noticeData = {
          'id': entry.key.toString(),
          'title': originalData['title']?.toString() ?? '',
          'content': originalData['content']?.toString() ?? '',
          'authorId': originalData['authorId']?.toString() ?? '',
          'authorName': originalData['authorName']?.toString() ?? '',
          'authorAvatar': originalData['authorAvatar']?.toString(),
          'imageUrl': originalData['imageUrl']?.toString(),
          'communityId': originalData['communityId']?.toString() ?? '',
          'createdAt': originalData['createdAt'] ?? 0,
          'updatedAt': originalData['updatedAt'] ?? 0,
          'likes': originalData['likes'] is Map ? originalData['likes'] : null,
          'comments': originalData['comments'] is Map ? originalData['comments'] : null,
        };
        return CommunityNotice.fromMap(noticeData);
      }).toList();

      // Sort by createdAt in descending order (newest first)
      notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notices;
    });
  }

  // Create a new notice
  Future<String> createNotice({
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    required String communityId,
  }) async {
    final newNoticeRef = _database.child('community_notices').push();
    await newNoticeRef.set({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': ServerValue.timestamp,
      'likes': null,
      'comments': null,
      'communityId': communityId,
    });
    return newNoticeRef.key!;
  }

  // Like a notice
  Future<void> likeNotice(String noticeId, String userId) async {
    final likesRef = _database
        .child('community_notices')
        .child(noticeId)
        .child('likes')
        .child(userId);

    final snapshot = await likesRef.get();
    if (snapshot.exists) {
      await likesRef.remove();
    } else {
      await likesRef.set({
        'createdAt': ServerValue.timestamp,
      });
    }
  }

  // Add a comment
  Future<void> addComment(
    String noticeId,
    String content,
    String authorId,
    String authorName,
    String? authorAvatar,
  ) async {
    final newCommentRef = _database
        .child('community_notices')
        .child(noticeId)
        .child('comments')
        .push();

    await newCommentRef.set({
      'content': content,
      'createdAt': ServerValue.timestamp,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
    });
  }

  // Delete a notice (only by author or admin)
  Future<void> deleteNotice(String noticeId) async {
    await _database.child('community_notices').child(noticeId).remove();
  }
}
