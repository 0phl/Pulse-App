import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Add Timer import
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import '../services/community_notice_service.dart';
import 'comment_text.dart';

class CommentsSheet extends StatefulWidget {
  final CommunityNotice notice;
  final VoidCallback? onCommentAdded;

  const CommentsSheet({
    Key? key,
    required this.notice,
    this.onCommentAdded,
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
  bool _isRefreshing = false;
  List<Comment> _comments = [];

  // Map to store user profile data
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
    // Add safety check for null or empty comments
    if (widget.notice.comments.isNotEmpty) {
      _comments = List.from(widget.notice.comments);
      _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      _comments = []; // Ensure _comments is initialized as an empty list if no comments
    }

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
          // Check if user is admin (in Firestore)
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(comment.authorId)
              .get();

          if (adminDoc.exists) {
            // Admin user
            final adminData = adminDoc.data() as Map<String, dynamic>;
            if (mounted) {
              setState(() {
                _userProfileCache[comment.authorId] = {
                  'profileImageUrl': adminData['profileImageUrl'],
                  'fullName': adminData['fullName'],
                  'isAdmin': true,
                };
              });
            }
          } else {
            // Regular user in RTDB
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
                    'isAdmin': false,
                  };
                });
              }
            }
          }
        } catch (e) {
          // Handle errors silently
        }

        // Also refresh profiles for replies
        for (final reply in comment.replies) {
          try {
            // Check if user is admin (in Firestore)
            final adminDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(reply.authorId)
                .get();

            if (adminDoc.exists) {
              // Admin user
              final adminData = adminDoc.data() as Map<String, dynamic>;
              if (mounted) {
                setState(() {
                  _userProfileCache[reply.authorId] = {
                    'profileImageUrl': adminData['profileImageUrl'],
                    'fullName': adminData['fullName'],
                    'isAdmin': true,
                  };
                });
              }
            } else {
              // Regular user in RTDB
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
                      'isAdmin': false,
                    };
                  });
                }
              }
            }
          } catch (e) {
            // Handle errors silently
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

        // Notify parent widget that comments were refreshed
        widget.onCommentAdded?.call();
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

        // Notify parent widget that a comment was liked/unliked
        widget.onCommentAdded?.call();
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

        String commentId;
        if (isAdmin) {
          commentId = await _adminService.addComment(
            widget.notice.id,
            commentContent,
            parentCommentId: _replyingTo?.id,
          );
        } else {
          commentId = await _noticeService.addComment(
            widget.notice.id,
            commentContent,
            user.uid,
            fullName,
            profileImageUrl,
            parentCommentId: _replyingTo?.id,
          );
        }

        // Create a temporary comment to show immediately
        final newComment = Comment(
          id: commentId,
          content: commentContent,
          authorId: user.uid,
          authorName: fullName,
          authorAvatar: profileImageUrl,
          createdAt: DateTime.now(),
          parentId: _replyingTo?.parentId ?? _replyingTo?.id,
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

        // Notify parent widget that a comment was added
        widget.onCommentAdded?.call();
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
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
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
              ],
            ),
          ),



          // Comments list with pull-to-refresh
          Flexible(
            child: RefreshIndicator(
              onRefresh: _refreshUserProfiles,
              child: _comments.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
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
                  : Stack(
                      children: [
                        ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 8,
                            // Add extra padding at the bottom to ensure content isn't hidden behind the keyboard
                            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                          ),
                          itemCount: _comments.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey[100],
                          ),
                          itemBuilder: (context, index) {
                            // Add safety check to prevent index out of range errors
                            if (index < 0 || index >= _comments.length) {
                              return const SizedBox.shrink(); // Return empty widget if index is invalid
                            }

                            final comment = _comments[index];

                            // Add safety check for empty author name
                            if (comment.authorName.isEmpty) {
                              return const SizedBox.shrink(); // Skip this comment if author name is empty
                            }

                            return _CommentItem(
                              comment: comment,
                              userProfile: _userProfileCache[comment.authorId],
                              isExpanded: _expandedComments.contains(comment.id),
                              onToggleExpanded: () => _toggleExpanded(comment.id),
                              onReply: () => _setReplyingTo(comment),
                              onLike: () => _likeComment(comment),
                              onLikeReply: (reply) => _likeComment(reply, parentId: comment.id),
                              onReplyToReply: (reply) => _setReplyingTo(reply), // Reply to the actual reply, not parent
                              replyUserProfiles: _userProfileCache,
                            );
                          },
                        ),
                        // Show loading indicator when refreshing
                        if (_isRefreshing)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // Reply banner (when replying to someone)
          if (_replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Replying to ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _replyingTo!.authorName.startsWith('Admin')
                          ? const Color(0xFF00C49A)
                          : Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _replyingTo!.authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Comment input
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: _replyingTo != null ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    filled: true,
                                    fillColor: Colors.grey[100],
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
    // Add safety check for empty author name
    if (comment.authorName.isEmpty) {
      return const SizedBox.shrink(); // Return empty widget if author name is empty
    }

    final bool isAdmin = comment.authorName.startsWith('Admin');
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
                backgroundImage: userProfile?['profileImageUrl'] != null
                    ? NetworkImage(userProfile!['profileImageUrl'] as String)
                    : (comment.authorAvatar != null
                        ? NetworkImage(comment.authorAvatar!)
                        : null),
                child: (userProfile?['profileImageUrl'] == null && comment.authorAvatar == null && comment.authorName.isNotEmpty)
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
                  // Add safety check for empty author name in replies
                  if (reply.authorName.isEmpty) {
                    return const SizedBox.shrink(); // Skip this reply if author name is empty
                  }

                  final bool isReplyAdmin = reply.authorName.startsWith('Admin');
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
                          backgroundImage: replyUserProfiles[reply.authorId]?['profileImageUrl'] != null
                              ? NetworkImage(replyUserProfiles[reply.authorId]!['profileImageUrl'] as String)
                              : (reply.authorAvatar != null
                                  ? NetworkImage(reply.authorAvatar!)
                                  : null),
                          child: (replyUserProfiles[reply.authorId]?['profileImageUrl'] == null &&
                                 reply.authorAvatar == null &&
                                 reply.authorName.isNotEmpty)
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
