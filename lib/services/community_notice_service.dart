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
        return CommunityNotice.fromMap(
            entry.key, entry.value as Map<dynamic, dynamic>);
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
      'likes': 0,
      'comments': 0,
      'communityId': communityId,
    });
    return newNoticeRef.key!;
  }

  // Like a notice
  Future<void> likeNotice(String noticeId) async {
    final noticeRef = _database.child('community_notices').child(noticeId);
    await noticeRef.child('likes').set(ServerValue.increment(1));
  }

  // Add a comment
  Future<void> addComment(String noticeId) async {
    final noticeRef = _database.child('community_notices').child(noticeId);
    await noticeRef.child('comments').set(ServerValue.increment(1));
  }

  // Delete a notice (only by author or admin)
  Future<void> deleteNotice(String noticeId) async {
    await _database.child('community_notices').child(noticeId).remove();
  }
}
