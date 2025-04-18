import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/community_notice.dart';
import '../services/community_notice_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'image_gallery_viewer.dart';

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
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
    return widget.notice.poll!.options.fold(0, (sum, option) => sum + option.voteCount);
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.notice.poll!;
    final totalVotes = _getTotalVotes();
    final isPollExpired = _isPollExpired();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) {
            final hasVoted = _hasVoted(option);
            final percentage = totalVotes > 0 ? (option.voteCount / totalVotes * 100).round() : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: isPollExpired || _isVoting ? null : () => _vote(option.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: hasVoted ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasVoted ? Colors.blue : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.text,
                              style: TextStyle(
                                fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                                color: hasVoted ? Colors.blue : null,
                              ),
                            ),
                          ),
                          if (hasVoted)
                            const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          color: hasVoted ? Colors.blue : Colors.grey[400],
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (isPollExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Poll ended',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Poll End Date'),
                        content: Text(
                          DateFormat('MMMM d, y h:mm a').format(poll.expiresAt.toLocal()),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    _formatExpiryDate(poll.expiresAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],
          ),
          if (poll.allowMultipleChoices) ...[
            const SizedBox(height: 8),
            Text(
              'Multiple choices allowed',
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class AttachmentWidget extends StatelessWidget {
  final FileAttachment attachment;

  const AttachmentWidget({super.key, required this.attachment});

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

  Future<void> _openFile(BuildContext context) async {
    try {
      final Uri url = Uri.parse(attachment.url);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _getIconForFileType(attachment.type),
                color: _getColorForFileType(attachment.type),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(attachment.size),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.download, color: Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
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
                // Image Gallery
                if (notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ...[
                  ImageGalleryViewer(
                    imageUrls: notice.imageUrls!,
                    height: 200,
                  ),
                  const SizedBox(height: 12),
                ],

                // Video Player
                if (notice.videoUrl != null) ...[
                  VideoPlayerWidget(videoUrl: notice.videoUrl!),
                  const SizedBox(height: 12),
                ],

                // Poll
                if (notice.poll != null) ...[
                  PollWidget(notice: notice),
                  const SizedBox(height: 12),
                ],

                // Attachments
                if (notice.attachments != null && notice.attachments!.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attachments',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...notice.attachments!.map((attachment) => AttachmentWidget(attachment: attachment)),
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
