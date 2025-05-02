import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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
      final data = event.snapshot.value;
      // Handle null data or empty data
      if (data == null) return [];

      // Handle case when data is not a Map
      if (data is! Map<dynamic, dynamic>) return [];

      final notices = <CommunityNotice>[];

      try {
        final dataMap = data as Map<dynamic, dynamic>;

        for (var entry in dataMap.entries) {
          try {
            if (entry.value is! Map<dynamic, dynamic>) continue;

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

            final notice = CommunityNotice.fromMap(noticeData);
            notices.add(notice);
          } catch (e) {
            debugPrint('Error parsing notice: ${e.toString()}');
            // Skip this notice and continue with the next one
            continue;
          }
        }
      } catch (e) {
        debugPrint('Error parsing notices: ${e.toString()}');
        return [];
      }

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
  Future<String> addComment(
    String noticeId,
    String content,
    String authorId,
    String authorName,
    String? authorAvatar,
    {String? parentCommentId}
  ) async {
    // If parentCommentId is provided, add as a reply to that comment
    if (parentCommentId != null) {
      // First, check if the parent comment is itself a reply by looking it up
      final parentCommentSnapshot = await _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(parentCommentId)
          .get();

      String actualParentId = parentCommentId;

      // Check if the parent comment exists
      if (parentCommentSnapshot.exists) {
        // Parent comment exists as a top-level comment
      } else {
        // If the parent comment doesn't exist as a top-level comment, it might be a reply

        // Search for the comment in all replies
        final allCommentsSnapshot = await _database
            .child('community_notices')
            .child(noticeId)
            .child('comments')
            .get();

        if (allCommentsSnapshot.exists) {
          final allComments = allCommentsSnapshot.value as Map<dynamic, dynamic>;

          // Iterate through all top-level comments
          for (var commentEntry in allComments.entries) {
            final comment = commentEntry.value as Map<dynamic, dynamic>;

            // Check if this comment has replies
            if (comment['replies'] is Map) {
              final replies = comment['replies'] as Map<dynamic, dynamic>;

              // Check if our target reply is in this comment's replies
              if (replies.containsKey(parentCommentId)) {
                // Found the actual parent comment
                actualParentId = commentEntry.key.toString();
                break;
              }
            }
          }
        }
      }



      final newReplyRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(actualParentId)
          .child('replies')
          .push();



      // Always store the replyToId, even if it's the same as the parentId
      // This is important for replies to admin comments
      await newReplyRef.set({
        'content': content,
        'createdAt': ServerValue.timestamp,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'parentId': actualParentId,
        'replyToId': parentCommentId, // Always store who we're replying to
      });

      return newReplyRef.key!;
    } else {
      // Add as a top-level comment
      // Debug print to help diagnose issues
      debugPrint('Adding top-level comment, Content: "$content"');

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

      return newCommentRef.key!;
    }
  }

  // Like or unlike a comment
  Future<void> likeComment(
    String noticeId,
    String commentId,
    String userId,
    {String? parentCommentId}
  ) async {
    final DatabaseReference likesRef;

    if (parentCommentId != null) {
      // Like a reply
      likesRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(parentCommentId)
          .child('replies')
          .child(commentId)
          .child('likes')
          .child(userId);
    } else {
      // Like a top-level comment
      likesRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(commentId)
          .child('likes')
          .child(userId);
    }

    final snapshot = await likesRef.get();
    if (snapshot.exists) {
      // Unlike if already liked
      await likesRef.remove();
    } else {
      // Like if not already liked
      await likesRef.set({
        'createdAt': ServerValue.timestamp,
      });
    }
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
    try {
      debugPrint('Starting deletion of notice: $noticeId');

      // First check if the notice exists
      final noticeSnapshot = await _database.child('community_notices').child(noticeId).get();
      if (!noticeSnapshot.exists) {
        debugPrint('Notice not found: $noticeId');
        throw Exception('Notice not found');
      }

      debugPrint('Notice found, proceeding with deletion');

      // Use a direct reference to the notice
      final noticeRef = _database.child('community_notices').child(noticeId);

      // We'll use direct deletion since Firebase RTDB transactions are complex
      bool deleteSuccess = false;

      // If transaction failed or wasn't supported, try direct deletion
      if (!deleteSuccess) {
        // Try set(null) first
        await noticeRef.set(null);
        debugPrint('Notice removal command sent using set(null)');

        // Add a small delay to ensure the deletion is processed
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify deletion was successful
        final verifySnapshot = await noticeRef.get();
        if (verifySnapshot.exists) {
          debugPrint('Notice still exists after set(null), trying remove()...');
          // If set(null) wasn't successful, try with remove() method
          await noticeRef.remove();
          await Future.delayed(const Duration(milliseconds: 500));

          // Final verification
          final finalVerifySnapshot = await noticeRef.get();
          if (finalVerifySnapshot.exists) {
            debugPrint('Notice still exists after remove() attempt');
            throw Exception('Failed to delete notice after multiple attempts');
          } else {
            debugPrint('Notice successfully deleted using remove()');
          }
        } else {
          debugPrint('Notice successfully deleted using set(null)');
        }
      }

      // Final success message
      debugPrint('Notice $noticeId successfully deleted');

    } catch (e) {
      debugPrint('Error deleting notice: $e');
      rethrow; // Rethrow to allow proper error handling by caller
    }
  }

  // Update all comments by a user when their profile changes
  Future<void> updateUserCommentsInfo(String userId, String newFullName, String? newProfileImageUrl) async {
    try {
      // Get all notices
      final noticesSnapshot = await _database.child('community_notices').get();
      if (!noticesSnapshot.exists) return;

      final notices = noticesSnapshot.value as Map<dynamic, dynamic>;

      // For each notice, check and update comments
      for (var noticeEntry in notices.entries) {
        final noticeId = noticeEntry.key.toString();
        final noticeData = noticeEntry.value as Map<dynamic, dynamic>;

        // Skip if no comments
        if (noticeData['comments'] == null || noticeData['comments'] is! Map) continue;

        final comments = noticeData['comments'] as Map<dynamic, dynamic>;

        // Check each top-level comment
        for (var commentEntry in comments.entries) {
          final commentId = commentEntry.key.toString();
          final commentData = commentEntry.value as Map<dynamic, dynamic>;

          // Update top-level comment if it's by this user
          if (commentData['authorId'] == userId) {
            await _database
                .child('community_notices')
                .child(noticeId)
                .child('comments')
                .child(commentId)
                .update({
              'authorName': newFullName,
              'authorAvatar': newProfileImageUrl,
            });
          }

          // Check and update replies
          if (commentData['replies'] != null && commentData['replies'] is Map) {
            final replies = commentData['replies'] as Map<dynamic, dynamic>;

            for (var replyEntry in replies.entries) {
              final replyId = replyEntry.key.toString();
              final replyData = replyEntry.value as Map<dynamic, dynamic>;

              // Update reply if it's by this user
              if (replyData['authorId'] == userId) {
                await _database
                    .child('community_notices')
                    .child(noticeId)
                    .child('comments')
                    .child(commentId)
                    .child('replies')
                    .child(replyId)
                    .update({
                  'authorName': newFullName,
                  'authorAvatar': newProfileImageUrl,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating user comments: $e');
      // Don't throw the error to prevent profile update from failing
    }
  }
}
