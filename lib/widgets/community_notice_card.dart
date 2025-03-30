import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/community_notice.dart' show CommunityNotice, Comment;
import '../services/community_notice_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'image_viewer_page.dart';

class CommentsPage extends StatefulWidget {
  final CommunityNotice notice;

  const CommentsPage({
    Key? key,
    required this.notice,
  }) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _noticeService = CommunityNoticeService();
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
        // Get user's full name from Realtime Database
        final userSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          final fullName = userData['fullName'] as String;

          await _noticeService.addComment(
            widget.notice.id,
            _commentController.text,
            user.uid,
            fullName,
            user.photoURL,
          );

          // Create a temporary comment to show immediately
          final newComment = Comment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: _commentController.text,
            authorId: user.uid,
            authorName: fullName,
            authorAvatar: user.photoURL,
            createdAt: DateTime.now(),
          );

          setState(() {
            _comments.insert(0, newComment);
            _commentController.clear();
          });
        }
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
                      child: Text(
                        widget.notice.authorName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF00C49A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

          // Comments list
          Expanded(
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
                      bottom: MediaQuery.of(context).padding.bottom,
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
                  FutureBuilder<DataSnapshot>(
                    future: FirebaseDatabase.instance
                        .ref()
                        .child('users')
                        .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                        .get(),
                    builder: (context, snapshot) {
                      String initial =
                          'S'; // Default to 'S' for better appearance
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData =
                            snapshot.data!.value as Map<dynamic, dynamic>;
                        initial = (userData['fullName'] as String)[0];
                      }
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue[50],
                        child: Text(
                          initial.toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                        IconButton(
                          onPressed: _isSubmitting ? null : _addComment,
                          icon: Icon(
                            Icons.send_rounded,
                            color: _commentController.text.isEmpty
                                ? Colors.grey[400]
                                : const Color(0xFF00C49A),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
    final bool isAdmin = comment.authorName.toLowerCase().contains('admin');

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
            child: Text(
              comment.authorName[0].toUpperCase(),
              style: TextStyle(
                color: isAdmin ? const Color(0xFF00C49A) : Colors.blue[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
}

class CommunityNoticeCard extends StatelessWidget {
  final CommunityNotice notice;
  final bool isAdmin;
  final Function()? onDelete;

  const CommunityNoticeCard({
    Key? key,
    required this.notice,
    this.isAdmin = false,
    this.onDelete,
  }) : super(key: key);

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
              child: Text(
                notice.authorName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF00C49A),
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                if (notice.imageUrl != null) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewerPage(
                            imageUrl: notice.imageUrl!,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: notice.imageUrl!,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          notice.imageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey[100],
                              child: const Center(
                                child: Icon(Icons.error_outline, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
                                ? Colors.red
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
