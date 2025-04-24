import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';

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
  bool _isSubmitting = false;
  List<Comment> _comments = [];

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

  Future<void> _addComment() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String fullName = 'Admin';  // Default name

        // Try to get admin data from Firestore first
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String? profileImageUrl;

        if (adminDoc.exists) {
          // User is an admin, get name from Firestore
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

        await _adminService.addComment(
          widget.notice.id,
          _commentController.text,
        );

        // Create a temporary comment to show immediately
        final newComment = Comment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: _commentController.text,
          authorId: user.uid,
          authorName: fullName,
          authorAvatar: profileImageUrl,
          createdAt: DateTime.now(),
        );

        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
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
                      return _CommentItem(comment: comment);
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
              child: Row(
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
                                hintText: 'Write a comment...',
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
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = comment.authorName.startsWith('Admin ');

    return Padding(
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
              ],
            ),
          ),
        ],
      ),
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
