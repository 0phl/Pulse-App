import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/community_notice.dart';
import '../services/community_notice_service.dart';
import '../services/file_downloader_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:async'; // Add Timer import
import 'media_gallery_widget.dart';
import 'multi_image_viewer_page.dart';
import 'file_download_progress.dart';
import 'image_viewer_page.dart';
import 'pdf_viewer_page.dart';
import 'video_player_page.dart';
import 'docx_viewer_page.dart';
import 'comment_text.dart';

class CommentsPage extends StatefulWidget {
  final CommunityNotice notice;

  const CommentsPage({
    super.key,
    required this.notice,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _noticeService = CommunityNoticeService();
  bool _isSubmitting = false;
  bool _isRefreshing = false;
  List<Comment> _comments = [];
  // Add a map to store user profile data
  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  // Timer for auto-refresh
  Timer? _refreshTimer;

  // Track which comment we're replying to (null if not replying)
  Comment? _replyingTo;

  // Track expanded comments (showing replies)
  final Set<String> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.notice.comments);
    _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Fetch latest user profiles when page opens
    _refreshUserProfiles();

    // Set up periodic refresh timer (every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isRefreshing) {
        _refreshUserProfiles();
      }
    });
  }

  // Method to refresh user profiles and comments
  Future<void> _refreshUserProfiles() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Refresh the comments directly from Firebase
      final commentsSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('community_notices')
          .child(widget.notice.id)
          .child('comments')
          .get();

      if (commentsSnapshot.exists && mounted) {
        final commentsData = commentsSnapshot.value as Map<dynamic, dynamic>;
        final List<Comment> updatedComments = [];

        // Convert Firebase data to Comment objects
        commentsData.forEach((key, value) {
          try {
            final commentData = value as Map<dynamic, dynamic>;
            // Add the ID to the map since Comment.fromMap expects it in the map
            commentData['id'] = key.toString();
            final comment = Comment.fromMap(commentData);
            updatedComments.add(comment);
          } catch (e) {
            // Skip invalid comments
          }
        });

        setState(() {
          _comments = updatedComments;
          _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }

      // Fetch user profiles for all comments and replies
      for (final comment in _comments) {
        try {
          final userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(comment.authorId)
              .get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            if (mounted) {
              setState(() {
                _userProfileCache[comment.authorId] = {
                  'profileImageUrl': userData['profileImageUrl'],
                  'fullName': userData['fullName'],
                };
              });
            }
          }
        } catch (e) {
          // Use a logger in production code
          // print('Error refreshing profile for ${comment.authorId}: $e');
        }

        // Also refresh profiles for replies
        for (final reply in comment.replies) {
          try {
            final userSnapshot = await FirebaseDatabase.instance
                .ref()
                .child('users')
                .child(reply.authorId)
                .get();

            if (userSnapshot.exists) {
              final userData = userSnapshot.value as Map<dynamic, dynamic>;
              if (mounted) {
                setState(() {
                  _userProfileCache[reply.authorId] = {
                    'profileImageUrl': userData['profileImageUrl'],
                    'fullName': userData['fullName'],
                  };
                });
              }
            }
          } catch (e) {
            // Use a logger in production code
            // print('Error refreshing profile for reply ${reply.authorId}: $e');
          }
        }
      }
    } catch (e) {
      // Handle any errors silently
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _refreshTimer?.cancel(); // Cancel the timer when the widget is disposed
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
    // Add safety check for invalid comment
    if (comment != null && (comment.id.isEmpty || comment.authorName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reply to this comment. Please try again.')),
      );
      return;
    }

    setState(() {
      _replyingTo = comment;
      if (comment != null) {
        // If this is a reply to a reply, we need to expand the parent comment
        if (comment.parentId != null && comment.parentId!.isNotEmpty) {
          _expandedComments.add(comment.parentId!);
        } else {
          // Ensure the comment is expanded when replying to a top-level comment
          _expandedComments.add(comment.id);
        }
      }
    });
  }

  // Like a comment
  Future<void> _likeComment(Comment comment, {String? parentId}) async {
    try {
      // Add safety check for invalid comment
      if (comment.id.isEmpty || comment.authorName.isEmpty) {
        return; // Skip liking if comment is invalid
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _noticeService.likeComment(
        widget.notice.id,
        comment.id,
        user.uid,
        parentCommentId: parentId,
      );

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

    // Add safety check for replying to an invalid comment
    if (_replyingTo != null && (_replyingTo!.id.isEmpty || _replyingTo!.authorName.isEmpty)) {
      setState(() => _replyingTo = null); // Reset invalid reply target
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reply to this comment. Please try again.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user's full name from Realtime Database
        final userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          final fullName = userData['fullName'] as String;
          final profileImageUrl = userData['profileImageUrl'] as String?;

          // Modify content to include @mention if replying to someone
          String commentContent = _commentController.text.trim();
          if (_replyingTo != null) {


            // If the user is replying but didn't type anything, just use the mention
            if (commentContent.isEmpty) {
              commentContent = '@${_replyingTo!.authorName}';
            } else {
              // Add a special delimiter to help identify where the mention ends and the comment begins
              // We'll use a double space as a delimiter
              commentContent = '@${_replyingTo!.authorName}  $commentContent';

            }
          }

          String commentId = await _noticeService.addComment(
            widget.notice.id,
            commentContent,
            user.uid,
            fullName,
            profileImageUrl,
            parentCommentId: _replyingTo?.id,
          );

          // Create a temporary comment to show immediately
          final newComment = Comment(
            id: commentId,
            content: commentContent,
            authorId: user.uid,
            authorName: fullName,
            authorAvatar: profileImageUrl,
            createdAt: DateTime.now(),
            // If replying to a reply, use the parent comment's ID as the parent
            parentId: _replyingTo?.parentId ?? _replyingTo?.id,
            // Store the ID of the specific comment being replied to
            replyToId: _replyingTo?.id,
          );



          setState(() {
            if (_replyingTo != null) {
              // Check if we're replying to a reply (has parentId) or a top-level comment
              if (_replyingTo!.parentId != null) {
                // We're replying to a reply, so we need to find the parent comment
                final parentIndex = _comments.indexWhere((c) => c.id == _replyingTo!.parentId);


                if (parentIndex >= 0) {
                  final updatedReplies = [..._comments[parentIndex].replies, newComment];
                  _comments[parentIndex] = _comments[parentIndex].copyWith(
                    replies: updatedReplies,
                  );
                }
              } else {
                // Add as a reply to an existing top-level comment
                final parentIndex = _comments.indexWhere((c) => c.id == _replyingTo!.id);


                if (parentIndex >= 0) {
                  final updatedReplies = [..._comments[parentIndex].replies, newComment];
                  _comments[parentIndex] = _comments[parentIndex].copyWith(
                    replies: updatedReplies,
                  );
                }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Comments', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00C49A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Post content
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF00C49A).withOpacity(0.1),
                      backgroundImage: widget.notice.authorAvatar != null
                          ? NetworkImage(widget.notice.authorAvatar!)
                          : null,
                      child: widget.notice.authorAvatar == null
                          ? Text(
                              widget.notice.authorName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF00C49A),
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
                                widget.notice.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeago.format(widget.notice.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (widget.notice.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.notice.content,
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[100],
              ),
            ],
          ),

          // Comments list with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshUserProfiles,
              child: _comments.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
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
                                const SizedBox(height: 16),
                                Text(
                                  'Pull down to refresh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: 8,
                        bottom: MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey[100],
                      ),
                      itemBuilder: (context, index) {
                        // Check if index is valid
                        if (index < 0 || index >= _comments.length) {
                          return const SizedBox.shrink(); // Return empty widget if index is invalid
                        }

                        final comment = _comments[index];
                        return _CommentItem(
                          comment: comment,
                          userProfile: _userProfileCache[comment.authorId],
                          isExpanded: _expandedComments.contains(comment.id),
                          onToggleExpanded: () => _toggleExpanded(comment.id),
                          onReply: () => _setReplyingTo(comment),
                          onLike: () => _likeComment(comment),
                          onLikeReply: (reply) => _likeComment(reply, parentId: comment.id),
                          onReplyToReply: (reply) => _setReplyingTo(reply), // Reply to the actual reply
                          replyUserProfiles: _userProfileCache,
                        );
                      },
                    ),
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
                  // Input row
                  Row(
                    children: [
                      FutureBuilder<DataSnapshot>(
                        future: FirebaseDatabase.instance
                            .ref()
                            .child('users')
                            .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                            .get(),
                        builder: (context, snapshot) {
                          String initial =
                              'S'; // Default to 'S' for better appearance
                          String? profileImageUrl;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.value as Map<dynamic, dynamic>;
                            initial = (userData['fullName'] as String)[0];
                            profileImageUrl = userData['profileImageUrl'] as String?;
                          }
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue[50],
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null
                                ? Text(
                                    initial.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.blue[700],
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
                                    prefixIcon: _replyingTo != null
                                        ? Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 8.0),
                                              child: IntrinsicWidth(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _replyingTo!.authorName.startsWith('Admin')
                                                        ? const Color(0xFF00C49A).withOpacity(0.1)
                                                        : Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '@${_replyingTo!.authorName}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: _replyingTo!.authorName.startsWith('Admin')
                                                              ? const Color(0xFF00C49A)
                                                              : Colors.blue[700],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      GestureDetector(
                                                        onTap: () => setState(() => _replyingTo = null),
                                                        child: Icon(
                                                          Icons.close,
                                                          size: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      if (_replyingTo != null) {
                                        // Allow empty text when replying (will just show the mention)
                                        return null;
                                      }
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
                                final hasText = value.text.isNotEmpty || _replyingTo != null;
                                return IconButton(
                                  onPressed: _isSubmitting ? null : (_replyingTo != null || hasText ? _addComment : null),
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: (_replyingTo != null || hasText)
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
  final Map<String, dynamic>? userProfile;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final Function(Comment) onLikeReply;
  final Function(Comment) onReplyToReply;
  final Map<String, Map<String, dynamic>> replyUserProfiles;

  const _CommentItem({
    required this.comment,
    this.userProfile,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onReply,
    required this.onLike,
    required this.onLikeReply,
    required this.onReplyToReply,
    required this.replyUserProfiles,
  });

  @override
  Widget build(BuildContext context) {
    // Add safety checks for null or empty values
    if (comment.authorName.isEmpty) {
      return const SizedBox.shrink(); // Return empty widget if author name is empty
    }

    final bool isAdmin = comment.authorName.startsWith('Admin');
    // Use updated profile image if available
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
                  // Add safety check for empty author name
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
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: false,
        looping: false,
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 30),
                const SizedBox(height: 8),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 30),
              const SizedBox(height: 8),
              Text(
                'Error loading video',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

class PollWidget extends StatefulWidget {
  final CommunityNotice notice;

  const PollWidget({super.key, required this.notice});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  final CommunityNoticeService _noticeService = CommunityNoticeService();
  bool _isVoting = false;
  String? _currentUserId;

  String _formatExpiryDate(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Poll ended';
    }

    if (difference.inDays > 7) {
      // For dates more than a week away, show "ends in X weeks"
      final weeks = (difference.inDays / 7).floor();
      return 'Ends in ${weeks == 1 ? '1 week' : '$weeks weeks'}';
    } else if (difference.inDays > 0) {
      // For dates within a week, show "ends in X days"
      return 'Ends in ${difference.inDays == 1 ? '1 day' : '${difference.inDays} days'}';
    } else if (difference.inHours > 0) {
      return 'Ends in ${difference.inHours == 1 ? '1 hour' : '${difference.inHours} hours'}';
    } else if (difference.inMinutes > 0) {
      return 'Ends in ${difference.inMinutes == 1 ? '1 minute' : '${difference.inMinutes} minutes'}';
    } else {
      return 'Ends in ${difference.inSeconds == 1 ? '1 second' : '${difference.inSeconds} seconds'}';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _vote(String optionId) async {
    if (_currentUserId == null || _isVoting) return;

    setState(() => _isVoting = true);

    try {
      await _noticeService.voteOnPoll(
        widget.notice.id,
        optionId,
        _currentUserId!,
        allowMultipleChoices: widget.notice.poll!.allowMultipleChoices,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  bool _hasVoted(PollOption option) {
    return _currentUserId != null && option.votedBy.contains(_currentUserId);
  }

  bool _isPollExpired() {
    return DateTime.now().isAfter(widget.notice.poll!.expiresAt);
  }

  int _getTotalVotes() {
    return widget.notice.poll!.options
        .fold(0, (sum, option) => sum + option.voteCount);
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.notice.poll!;
    final totalVotes = _getTotalVotes();
    final isPollExpired = _isPollExpired();
    const appThemeColor = Color(0xFF00C49A);
    final hasImages =
        (widget.notice.imageUrls != null && widget.notice.imageUrls!.isNotEmpty) ||
        (widget.notice.poll!.imageUrls != null && widget.notice.poll!.imageUrls!.isNotEmpty);

    // If this poll has images and is displayed in the combined container,
    // we need a simpler layout without duplicate headers
    if (hasImages) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...poll.options.map((option) {
            final hasVoted = _hasVoted(option);
            final percentage = totalVotes > 0
                ? (option.voteCount / totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap:
                    isPollExpired || _isVoting ? null : () => _vote(option.id),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? appThemeColor.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVoted ? appThemeColor : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasVoted)
                            Container(
                              padding: const EdgeInsets.all(2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: appThemeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasVoted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    hasVoted ? appThemeColor : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: hasVoted ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart,
                            height: 6,
                            width: MediaQuery.of(context).size.width *
                                percentage /
                                100 *
                                0.7,
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : appThemeColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isPollExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off,
                          size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Poll ended',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: appThemeColor),
                            const SizedBox(width: 8),
                            const Text('Poll End Date'),
                          ],
                        ),
                        content: Text(
                          DateFormat('MMMM d, y h:mm a')
                              .format(poll.expiresAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close',
                                style: TextStyle(color: appThemeColor)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: appThemeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: appThemeColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryDate(poll.expiresAt),
                          style: TextStyle(
                            color: appThemeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (poll.allowMultipleChoices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Multiple choices allowed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Standard poll display without images
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, color: appThemeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...poll.options.map((option) {
            final hasVoted = _hasVoted(option);
            final percentage = totalVotes > 0
                ? (option.voteCount / totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap:
                    isPollExpired || _isVoting ? null : () => _vote(option.id),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? appThemeColor.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVoted ? appThemeColor : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (hasVoted)
                            Container(
                              padding: const EdgeInsets.all(2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: appThemeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasVoted
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    hasVoted ? appThemeColor : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: TextStyle(
                                color: hasVoted ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart,
                            height: 6,
                            width: MediaQuery.of(context).size.width *
                                percentage /
                                100 *
                                0.7,
                            decoration: BoxDecoration(
                              color: hasVoted
                                  ? appThemeColor
                                  : appThemeColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (isPollExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_off,
                          size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Poll ended',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: appThemeColor),
                            const SizedBox(width: 8),
                            const Text('Poll End Date'),
                          ],
                        ),
                        content: Text(
                          DateFormat('MMMM d, y h:mm a')
                              .format(poll.expiresAt.toLocal()),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close',
                                style: TextStyle(color: appThemeColor)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: appThemeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: appThemeColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatExpiryDate(poll.expiresAt),
                          style: TextStyle(
                            color: appThemeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (poll.allowMultipleChoices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Multiple choices allowed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AttachmentWidget extends StatefulWidget {
  final FileAttachment attachment;

  const AttachmentWidget({super.key, required this.attachment});

  @override
  State<AttachmentWidget> createState() => _AttachmentWidgetState();
}

class _AttachmentWidgetState extends State<AttachmentWidget> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final _fileDownloader = FileDownloaderService();

  IconData _getIconForFileType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForFileType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _downloadAndOpenFile() async {
    // Check file type to determine how to handle it
    final fileType = widget.attachment.type.toLowerCase();
    final url = widget.attachment.url;
    final fileName = widget.attachment.name;

    // Handle different file types
    if (fileType == 'pdf' || url.toLowerCase().contains('.pdf')) {
      // Open PDF in the PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(
            pdfUrl: url,
            fileName: fileName,
          ),
        ),
      );
    } else if (fileType == 'doc' || fileType == 'docx' || url.toLowerCase().contains('.doc') || url.toLowerCase().contains('.docx')) {
      // Open DOCX in the DOCX viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocxViewerPage(
            docxUrl: url,
            fileName: fileName,
          ),
        ),
      );
    } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileType)) {
      // Open image in the image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            imageUrl: url,
          ),
        ),
      );
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(fileType)) {
      // Open video in the video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            videoUrl: url,
          ),
        ),
      );
    } else {
      // For other file types, download and open using the system
      if (_isDownloading) return;

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      try {
        // Show download options dialog
        final bool? shouldDownload = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download File'),
            content: Text('Do you want to download "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Download'),
              ),
            ],
          ),
        );

        if (shouldDownload != true || !mounted) return;

        // Download and save to PULSE album
        await _fileDownloader.downloadAndSaveToPulseAlbum(
          url: url,
          fileName: fileName,
          context: context,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
          },
        );
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: InkWell(
            onTap: _downloadAndOpenFile,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _getIconForFileType(widget.attachment.type),
                    color: _getColorForFileType(widget.attachment.type),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.attachment.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(widget.attachment.size),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isDownloading ? Icons.downloading : Icons.download,
                    color: _isDownloading ? const Color(0xFF00C49A) : Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isDownloading)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                      maxHeight: 100, // Limit the height to prevent overflow
                    ),
                    child: FileDownloadProgress(
                      progress: _downloadProgress,
                      fileName: widget.attachment.name,
                      onCancel: () {
                        setState(() {
                          _isDownloading = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CommunityNoticeCard extends StatelessWidget {
  final CommunityNotice notice;
  final bool isAdmin;
  final Function()? onDelete;

  const CommunityNoticeCard({
    super.key,
    required this.notice,
    this.isAdmin = false,
    this.onDelete,
  });

  // Format expiry date for poll display
  String _formatExpiryDate(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Poll ended';
    }

    if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return 'Ends in ${weeks == 1 ? '1 week' : '$weeks weeks'}';
    } else if (difference.inDays > 0) {
      return 'Ends in ${difference.inDays == 1 ? '1 day' : '${difference.inDays} days'}';
    } else if (difference.inHours > 0) {
      return 'Ends in ${difference.inHours == 1 ? '1 hour' : '${difference.inHours} hours'}';
    } else if (difference.inMinutes > 0) {
      return 'Ends in ${difference.inMinutes == 1 ? '1 minute' : '${difference.inMinutes} minutes'}';
    } else {
      return 'Ends in ${difference.inSeconds == 1 ? '1 second' : '${difference.inSeconds} seconds'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommunityNoticeService noticeService = CommunityNoticeService();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00C49A).withOpacity(0.1),
              backgroundImage: notice.authorAvatar != null
                  ? NetworkImage(notice.authorAvatar!)
                  : null,
              child: notice.authorAvatar == null
                  ? Text(
                      notice.authorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00C49A),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              notice.authorName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              timeago.format(notice.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: isAdmin
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: Colors.red[400],
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C49A),
                  ),
                ),
                const SizedBox(height: 12),

                // Handle media display based on content type
                // Case 1: Poll with images - handled in the poll section below
                // Case 2: Media without poll - handled here
                if (notice.poll == null &&
                    ((notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ||
                     notice.videoUrl != null)) ...[
                  MediaGalleryWidget(
                    imageUrls: notice.imageUrls,
                    videoUrl: notice.videoUrl,
                    height: 250,
                  ),
                  const SizedBox(height: 12),
                ],

                // Poll with images
                if (notice.poll != null &&
                    ((notice.poll!.imageUrls != null && notice.poll!.imageUrls!.isNotEmpty) ||
                     (notice.imageUrls != null && notice.imageUrls!.isNotEmpty))) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image at the top
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: PageView.builder(
                              itemCount: (notice.poll!.imageUrls != null && notice.poll!.imageUrls!.isNotEmpty)
                                  ? notice.poll!.imageUrls!.length
                                  : notice.imageUrls!.length,
                              itemBuilder: (context, index) {
                                final imageUrls = (notice.poll!.imageUrls != null && notice.poll!.imageUrls!.isNotEmpty)
                                    ? notice.poll!.imageUrls!
                                    : notice.imageUrls!;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MultiImageViewerPage(
                                          imageUrls: imageUrls,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          color: const Color(0xFF00C49A),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey[400],
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Poll content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.poll_outlined,
                                      color: Color(0xFF00C49A), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      notice.poll!.question,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Poll options
                              ...notice.poll!.options.map((option) {
                                final totalVotes = notice.poll!.options
                                    .fold(0, (sum, opt) => sum + opt.voteCount);
                                final percentage = totalVotes > 0
                                    ? (option.voteCount / totalVotes * 100)
                                        .round()
                                    : 0;
                                final hasVoted = FirebaseAuth
                                            .instance.currentUser !=
                                        null &&
                                    option.votedBy.contains(
                                        FirebaseAuth.instance.currentUser!.uid);
                                final isPollExpired = DateTime.now().isAfter(notice.poll!.expiresAt);
                                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                                // Track voting state locally
                                bool isVoting = false;

                                return GestureDetector(
                                  onTap: () async {
                                    // Don't allow voting if poll expired or user not logged in
                                    if (isPollExpired || currentUserId == null || isVoting) {
                                      return;
                                    }

                                    // Set local voting state
                                    isVoting = true;

                                    try {
                                      await noticeService.voteOnPoll(
                                        notice.id,
                                        option.id,
                                        currentUserId,
                                        allowMultipleChoices:
                                            notice.poll!.allowMultipleChoices,
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error voting: $e')),
                                        );
                                      }
                                    } finally {
                                      isVoting = false;
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: hasVoted
                                          ? const Color(0xFF00C49A)
                                              .withOpacity(0.1)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: hasVoted
                                            ? const Color(0xFF00C49A)
                                            : Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (hasVoted)
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(2),
                                                margin: const EdgeInsets.only(
                                                    right: 8),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00C49A),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                option.text,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: hasVoted
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: hasVoted
                                                      ? const Color(0xFF00C49A)
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: hasVoted
                                                    ? const Color(0xFF00C49A)
                                                    : Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$percentage%',
                                                style: TextStyle(
                                                  color: hasVoted
                                                      ? Colors.white
                                                      : Colors.black54,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Stack(
                                          children: [
                                            Container(
                                              height: 6,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 500),
                                              curve: Curves.easeOutQuart,
                                              height: 6,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  percentage /
                                                  100 *
                                                  0.7,
                                              decoration: BoxDecoration(
                                                color: hasVoted
                                                    ? const Color(0xFF00C49A)
                                                    : const Color(0xFF00C49A)
                                                        .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              // Poll info footer
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Vote count
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.how_to_vote_outlined,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${notice.poll!.options.fold(0, (sum, opt) => sum + opt.voteCount)} votes',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Poll expiration
                                  DateTime.now().isAfter(notice.poll!.expiresAt)
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.timer_off,
                                                  size: 12,
                                                  color: Colors.red.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Poll ended',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C49A)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.timer_outlined,
                                                size: 12,
                                                color: Color(0xFF00C49A),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatExpiryDate(
                                                    notice.poll!.expiresAt),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF00C49A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ],
                              ),

                              // Multiple choices indicator if applicable
                              if (notice.poll!.allowMultipleChoices) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Multiple choices allowed',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (notice.poll != null) ...[
                  // Regular poll without images
                  PollWidget(notice: notice),
                  const SizedBox(height: 12),
                ],

                // Attachments
                if (notice.attachments != null &&
                    notice.attachments!.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attachments',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...notice.attachments!.map((attachment) =>
                          AttachmentWidget(attachment: attachment)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  notice.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await noticeService.likeNotice(
                                  notice.id, user.uid);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                notice.isLikedBy(FirebaseAuth
                                            .instance.currentUser?.uid ??
                                        '')
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 20,
                                color: notice.isLikedBy(FirebaseAuth
                                            .instance.currentUser?.uid ??
                                        '')
                                    ? const Color(0xFF00C49A)
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                notice.likesCount.toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CommentsPage(notice: notice),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                notice.commentsCount.toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Implement share functionality
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.share_outlined,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
