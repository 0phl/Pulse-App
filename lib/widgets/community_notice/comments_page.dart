import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/community_notice.dart';
import '../../services/community_notice_service.dart';
import 'comment_item.dart';

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
  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  Timer? _refreshTimer;
  Comment? _replyingTo;
  final Set<String> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.notice.comments);
    _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _refreshUserProfiles();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isRefreshing) {
        _refreshUserProfiles();
      }
    });
  }

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
            // print('Error refreshing profile for reply ${reply.authorId}: $e');
          }
        }
      }
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

  void _setReplyingTo(Comment? comment) {
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

      setState(() {
        if (parentId != null) {
          final parentIndex = _comments.indexWhere((c) => c.id == parentId);
          if (parentIndex >= 0) {
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

          final newComment = Comment(
            id: commentId,
            content: commentContent,
            authorId: user.uid,
            authorName: fullName,
            authorAvatar: profileImageUrl,
            createdAt: DateTime.now(),
            // If replying to a reply, use the parent comment's ID as the parent
            parentId: _replyingTo?.parentId ?? _replyingTo?.id,
            replyToId: _replyingTo?.id,
          );

          setState(() {
            if (_replyingTo != null) {
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
      resizeToAvoidBottomInset: true,
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
                        bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                      ),
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey[100],
                      ),
                      itemBuilder: (context, index) {
                        if (index < 0 || index >= _comments.length) {
                          return const SizedBox.shrink();
                        }

                        final comment = _comments[index];
                        return CommentItem(
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
    );
  }
}
