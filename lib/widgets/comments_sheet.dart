import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import '../services/community_notice_service.dart';

class CommentsSheet extends StatefulWidget {
  final CommunityNotice notice;

  const CommentsSheet({
    Key? key,
    required this.notice,
  }) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _adminService = AdminService();
  final _noticeService = CommunityNoticeService();
  bool _isSubmitting = false;
  List<Comment> _comments = [];

  // Track which comment we're replying to (null if not replying)
  Comment? _replyingTo;

  // Track expanded comments (showing replies)
  final Set<String> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.notice.comments);
    _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Toggle expanded state of a comment
  void _toggleExpanded(String commentId) {
    setState(() {
      if (_expandedComments.contains(commentId)) {
        _expandedComments.remove(commentId);
      } else {
        _expandedComments.add(commentId);
      }
    });
  }

  // Set replying to a comment
  void _setReplyingTo(Comment? comment) {
    setState(() {
      _replyingTo = comment;
      if (comment != null) {
        // Ensure the comment is expanded when replying
        _expandedComments.add(comment.id);
      }
    });
  }

  // Like a comment
  Future<void> _likeComment(Comment comment, {String? parentId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user is admin
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        // Admin user
        await _adminService.likeComment(
          widget.notice.id,
          comment.id,
          parentCommentId: parentId,
        );
      } else {
        // Regular user
        await _noticeService.likeComment(
          widget.notice.id,
          comment.id,
          user.uid,
          parentCommentId: parentId,
        );
      }

      // Update UI immediately
      setState(() {
        if (parentId != null) {
          // Find parent comment
          final parentIndex = _comments.indexWhere((c) => c.id == parentId);
          if (parentIndex >= 0) {
            // Find reply in parent's replies
            final replyIndex = _comments[parentIndex].replies.indexWhere((r) => r.id == comment.id);
            if (replyIndex >= 0) {
              final reply = _comments[parentIndex].replies[replyIndex];
              final updatedReplies = List<Comment>.from(_comments[parentIndex].replies);

              if (reply.isLikedBy(user.uid)) {
                // Unlike
                updatedReplies[replyIndex] = reply.copyWith(
                  likedBy: reply.likedBy.where((id) => id != user.uid).toList(),
                );
              } else {
                // Like
                updatedReplies[replyIndex] = reply.copyWith(
                  likedBy: [...reply.likedBy, user.uid],
                );
              }

              _comments[parentIndex] = _comments[parentIndex].copyWith(
                replies: updatedReplies,
              );
            }
          }
        } else {
          // Top-level comment
          final index = _comments.indexWhere((c) => c.id == comment.id);
          if (index >= 0) {
            if (_comments[index].isLikedBy(user.uid)) {
              // Unlike
              _comments[index] = _comments[index].copyWith(
                likedBy: _comments[index].likedBy.where((id) => id != user.uid).toList(),
              );
            } else {
              // Like
              _comments[index] = _comments[index].copyWith(
                likedBy: [..._comments[index].likedBy, user.uid],
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking comment: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String fullName = 'Admin';  // Default name
        String? profileImageUrl;
        bool isAdmin = false;

        // Try to get admin data from Firestore first
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (adminDoc.exists) {
          // User is an admin, get name from Firestore
          isAdmin = true;
          final adminData = adminDoc.data() as Map<String, dynamic>;
          fullName = 'Admin ${adminData['fullName'] as String}';
          profileImageUrl = adminData['profileImageUrl'] as String?;
        } else {
          // If not in Firestore, try RTDB (for regular users)
          final userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(user.uid)
              .get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            fullName = userData['fullName'] as String;
            profileImageUrl = userData['profileImageUrl'] as String?;
          }
        }

        String commentId;
        if (isAdmin) {
          commentId = await _adminService.addComment(
            widget.notice.id,
            _commentController.text,
            parentCommentId: _replyingTo?.id,
          );
        } else {
          commentId = await _noticeService.addComment(
            widget.notice.id,
            _commentController.text,
            user.uid,
            fullName,
            profileImageUrl,
            parentCommentId: _replyingTo?.id,
          );
        }

        // Create a temporary comment to show immediately
        final newComment = Comment(
          id: commentId,
          content: _commentController.text,
          authorId: user.uid,
          authorName: fullName,
          authorAvatar: profileImageUrl,
          createdAt: DateTime.now(),
          parentId: _replyingTo?.id,
        );

        setState(() {
          if (_replyingTo != null) {
            // Add as a reply to an existing comment
            final parentIndex = _comments.indexWhere((c) => c.id == _replyingTo!.id);
            if (parentIndex >= 0) {
              final updatedReplies = [..._comments[parentIndex].replies, newComment];
              _comments[parentIndex] = _comments[parentIndex].copyWith(
                replies: updatedReplies,
              );
            }
            // Clear replying state
            _replyingTo = null;
          } else {
            // Add as a top-level comment
            _comments.insert(0, newComment);
          }
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_replyingTo != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel Reply'),
                  ),
                ],
              ],
            ),
          ),

          // Comments list
          Flexible(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 80,
                    ),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[100],
                    ),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _CommentItem(
                        comment: comment,
                        isExpanded: _expandedComments.contains(comment.id),
                        onToggleExpanded: () => _toggleExpanded(comment.id),
                        onReply: () => _setReplyingTo(comment),
                        onLike: () => _likeComment(comment),
                        onLikeReply: (reply) => _likeComment(reply, parentId: comment.id),
                        onReplyToReply: (reply) => _setReplyingTo(comment), // Reply to parent, not to reply
                      );
                    },
                  ),
          ),

          // Comment input
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show who we're replying to
                  if (_replyingTo != null)
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      width: double.infinity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Replying to ${_replyingTo!.authorName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input row
                  Row(
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: () async {
                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId == null) return {'initial': 'A', 'profileImageUrl': null};

                          // Check Firestore first for admin
                          final adminDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get();

                          if (adminDoc.exists) {
                            final adminData = adminDoc.data() as Map<String, dynamic>;
                            return {
                              'initial': (adminData['fullName'] as String)[0],
                              'profileImageUrl': adminData['profileImageUrl'] as String?,
                              'isAdmin': true
                            };
                          }

                          // If not in Firestore, check RTDB for regular users
                          final userSnapshot = await FirebaseDatabase.instance
                              .ref()
                              .child('users')
                              .child(userId)
                              .get();

                          if (userSnapshot.exists) {
                            final userData = userSnapshot.value as Map<dynamic, dynamic>;
                            return {
                              'initial': (userData['fullName'] as String)[0],
                              'profileImageUrl': userData['profileImageUrl'] as String?,
                              'isAdmin': false
                            };
                          }

                          return {'initial': 'A', 'profileImageUrl': null, 'isAdmin': false};
                        }(),
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? {'initial': 'A', 'profileImageUrl': null, 'isAdmin': false};
                          final initial = data['initial'] as String;
                          final profileImageUrl = data['profileImageUrl'] as String?;
                          final isAdmin = data['isAdmin'] as bool;

                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: isAdmin
                                ? const Color(0xFF00C49A).withOpacity(0.1)
                                : Colors.blue[50],
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    initial.toUpperCase(),
                                    style: TextStyle(
                                      color: isAdmin ? const Color(0xFF00C49A) : Colors.blue[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Form(
                                key: _formKey,
                                child: TextFormField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: _replyingTo != null
                                        ? 'Write a reply...'
                                        : 'Write a comment...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a comment';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _commentController,
                              builder: (context, value, child) {
                                final hasText = value.text.isNotEmpty;
                                return IconButton(
                                  onPressed: _isSubmitting || !hasText ? null : _addComment,
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: hasText
                                        ? const Color(0xFF00C49A)
                                        : Colors.grey[400],
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final Function(Comment) onLikeReply;
  final Function(Comment) onReplyToReply;

  const _CommentItem({
    required this.comment,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onReply,
    required this.onLike,
    required this.onLikeReply,
    required this.onReplyToReply,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = comment.authorName.startsWith('Admin ');
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
                backgroundImage: comment.authorAvatar != null
                    ? NetworkImage(comment.authorAvatar!)
                    : null,
                child: comment.authorAvatar == null
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
                          _formatTimeAgo(comment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Like and reply buttons
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: onLike,
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
                        const SizedBox(width: 16),
                        // Reply button
                        InkWell(
                          onTap: onReply,
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
                        if (hasReplies) ...[
                          const SizedBox(width: 16),
                          // Show/hide replies button
                          InkWell(
                            onTap: onToggleExpanded,
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
                  final bool isReplyAdmin = reply.authorName.startsWith('Admin ');
                  final bool isReplyLiked = currentUserId != null && reply.isLikedBy(currentUserId);

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
                          backgroundImage: reply.authorAvatar != null
                              ? NetworkImage(reply.authorAvatar!)
                              : null,
                          child: reply.authorAvatar == null
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
                                    _formatTimeAgo(reply.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reply.content,
                                style: const TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Like and reply buttons for replies
                              Row(
                                children: [
                                  // Like button
                                  InkWell(
                                    onTap: () => onLikeReply(reply),
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
                                  const SizedBox(width: 12),
                                  // Reply button
                                  InkWell(
                                    onTap: () => onReplyToReply(reply),
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

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
