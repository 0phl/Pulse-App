import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/community_notice.dart';
import '../comment_text.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final Map<String, dynamic>? userProfile;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final Function(Comment) onLikeReply;
  final Function(Comment) onReplyToReply;
  final Map<String, Map<String, dynamic>> replyUserProfiles;

  const CommentItem({
    Key? key,
    required this.comment,
    this.userProfile,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onReply,
    required this.onLike,
    required this.onLikeReply,
    required this.onReplyToReply,
    required this.replyUserProfiles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (comment.authorName.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isAdmin = comment.authorName.startsWith('Admin');
    final String? updatedProfileUrl = userProfile?['profileImageUrl'] as String?;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isLiked = currentUserId != null && comment.isLikedBy(currentUserId);
    final hasReplies = comment.replies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main comment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isAdmin
                    ? const Color(0xFF00C49A).withOpacity(0.1)
                    : Colors.blue[50],
                backgroundImage: updatedProfileUrl != null
                    ? NetworkImage(updatedProfileUrl)
                    : (comment.authorAvatar != null
                        ? NetworkImage(comment.authorAvatar!)
                        : null),
                child: (updatedProfileUrl == null && comment.authorAvatar == null)
                    ? Text(
                        comment.authorName[0].toUpperCase(),
                        style: TextStyle(
                          color: isAdmin ? const Color(0xFF00C49A) : Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color:
                                isAdmin ? const Color(0xFF00C49A) : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(comment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CommentText(
                      text: comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      mentionColor: isAdmin ? const Color(0xFF00C49A) : Colors.blue[700]!,
                    ),
                    const SizedBox(height: 8),
                    // Like and reply buttons
                    Row(
                      children: [
                        // Like button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onLike,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 16,
                                    color: isLiked ? const Color(0xFF00C49A) : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    comment.likesCount.toString(),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Reply button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onReply,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.reply,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (hasReplies) ...[
                          const SizedBox(width: 16),
                          // Show/hide replies button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onToggleExpanded,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isExpanded ? 'Hide replies' : 'Show ${comment.repliesCount} ${comment.repliesCount == 1 ? 'reply' : 'replies'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Replies section
        if (hasReplies && isExpanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.only(left: 40),
              child: Column(
                children: comment.replies.map((reply) {
                  if (reply.authorName.isEmpty) {
                    return const SizedBox.shrink(); // Skip this reply if author name is empty
                  }

                  final bool isReplyAdmin = reply.authorName.startsWith('Admin');
                  final bool isReplyLiked = currentUserId != null && reply.isLikedBy(currentUserId);
                  final String? replyProfileUrl = replyUserProfiles[reply.authorId]?['profileImageUrl'] as String?;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isReplyAdmin
                              ? const Color(0xFF00C49A).withOpacity(0.1)
                              : Colors.blue[50],
                          backgroundImage: replyProfileUrl != null
                              ? NetworkImage(replyProfileUrl)
                              : (reply.authorAvatar != null
                                  ? NetworkImage(reply.authorAvatar!)
                                  : null),
                          child: (replyProfileUrl == null && reply.authorAvatar == null)
                              ? Text(
                                  reply.authorName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: isReplyAdmin ? const Color(0xFF00C49A) : Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    reply.authorName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: isReplyAdmin ? const Color(0xFF00C49A) : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    timeago.format(reply.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              CommentText(
                                text: reply.content,
                                style: const TextStyle(
                                  fontSize: 13,
                                ),
                                mentionColor: isReplyAdmin ? const Color(0xFF00C49A) : Colors.blue[700]!,
                              ),
                              const SizedBox(height: 4),
                              // Like and reply buttons for replies
                              Row(
                                children: [
                                  // Like button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => onLikeReply(reply),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isReplyLiked ? Icons.favorite : Icons.favorite_border,
                                              size: 14,
                                              color: isReplyLiked ? const Color(0xFF00C49A) : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              reply.likesCount.toString(),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Reply button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => onReplyToReply(reply),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.reply,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Reply',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
