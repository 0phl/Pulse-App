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
          'imageUrls': originalData['imageUrls'] is List ? originalData['imageUrls'] : null,
          'communityId': originalData['communityId']?.toString() ?? '',
          'createdAt': originalData['createdAt'] ?? 0,
          'updatedAt': originalData['updatedAt'] ?? 0,
          'likes': originalData['likes'] is Map ? originalData['likes'] : null,
          'comments': originalData['comments'] is Map ? originalData['comments'] : null,
          'poll': originalData['poll'] is Map ? originalData['poll'] : null,
          'videoUrl': originalData['videoUrl']?.toString(),
          'attachments': originalData['attachments'] is List ? originalData['attachments'] : null,
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
    List<String>? imageUrls,
    String? videoUrl,
    Map<String, dynamic>? poll,
    List<Map<String, dynamic>>? attachments,
    String? authorAvatar,
  }) async {
    final newNoticeRef = _database.child('community_notices').push();
    await newNoticeRef.set({
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'poll': poll,
      'attachments': attachments,
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
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

  // Vote on a poll
  Future<void> voteOnPoll(
    String noticeId,
    String optionId,
    String userId,
    {bool allowMultipleChoices = false}
  ) async {
    // Get the current poll data
    final pollRef = _database
        .child('community_notices')
        .child(noticeId)
        .child('poll');

    final pollSnapshot = await pollRef.get();
    if (!pollSnapshot.exists) {
      throw Exception('Poll not found');
    }

    final pollData = pollSnapshot.value as Map<dynamic, dynamic>;
    final options = pollData['options'] as List<dynamic>;
    final selectedOption = options[int.parse(optionId)];

    // Check if the user has already voted for this option
    final hasVoted = selectedOption['votedBy'] != null &&
                     (selectedOption['votedBy'] as Map<dynamic, dynamic>?)?.containsKey(userId) == true;

    if (hasVoted) {
      // Remove the vote if already voted
      await pollRef
          .child('options')
          .child(optionId)
          .child('votedBy')
          .child(userId)
          .remove();
    } else {
      // If multiple choices are not allowed, remove any existing votes by this user
      if (!allowMultipleChoices) {
        for (var option in options) {
          if (option['votedBy'] != null) {
            await pollRef
                .child('options')
                .child(options.indexOf(option).toString())
                .child('votedBy')
                .child(userId)
                .remove();
          }
        }
      }

      // Add the new vote
      await pollRef
          .child('options')
          .child(optionId)
          .child('votedBy')
          .child(userId)
          .set({
        'timestamp': ServerValue.timestamp,
      });
    }
  }

  // Create a poll for a notice
  Future<void> createPoll(
    String noticeId,
    String question,
    List<String> options,
    DateTime expiresAt,
    {bool allowMultipleChoices = false}
  ) async {
    final pollRef = _database
        .child('community_notices')
        .child(noticeId)
        .child('poll');

    final Map<String, dynamic> pollData = {
      'question': question,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'allowMultipleChoices': allowMultipleChoices,
      'options': options.asMap().entries.map((entry) => {
        'id': entry.key.toString(),
        'text': entry.value,
        'votedBy': null,
      }).toList(),
    };

    await pollRef.set(pollData);
  }

  // Delete a notice (only by author or admin)
  Future<void> deleteNotice(String noticeId) async {
    await _database.child('community_notices').child(noticeId).remove();
  }
}
