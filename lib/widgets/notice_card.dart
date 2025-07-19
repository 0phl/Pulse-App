import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import '../services/file_downloader_service.dart';
import 'comments_sheet.dart';
import 'image_gallery_viewer.dart';
import 'video_player_page.dart';
import 'media_gallery_widget.dart';
import 'multi_image_viewer_page.dart';
import 'poll_voters_dialog.dart';
import 'poll_all_voters_dialog.dart';
import 'file_download_progress.dart';
import 'image_viewer_page.dart';
import 'pdf_viewer_page.dart';
import 'docx_viewer_page.dart';

class NoticeCard extends StatefulWidget {
  final CommunityNotice notice;
  final Function()? onEdit;
  final Function()? onDelete;
  final Function()? onRefresh;

  const NoticeCard({
    super.key,
    required this.notice,
    this.onEdit,
    this.onDelete,
    this.onRefresh,
  });

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  late CommunityNotice _notice;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
  }

  @override
  void didUpdateWidget(NoticeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice != widget.notice) {
      setState(() {
        _notice = widget.notice;
      });
    }
  }

  // Method to update like status locally
  void _toggleLike() {
    final currentUserId = _adminService.currentUserId ?? '';
    final isLiked = _notice.isLikedBy(currentUserId);

    List<String> updatedLikedBy = List.from(_notice.likedBy);
    if (isLiked) {
      updatedLikedBy.remove(currentUserId);
    } else {
      updatedLikedBy.add(currentUserId);
    }

    setState(() {
      _notice = _notice.copyWith(likedBy: updatedLikedBy);
    });

    // Perform the actual API call in the background
    _adminService.toggleNoticeLike(_notice.id);
  }

  // Method to refresh notice data after comments are added/liked
  Future<void> _refreshNoticeData() async {
    try {
      final updatedNotices = await _adminService.getNotices();

      final updatedNotice = updatedNotices.firstWhere(
        (n) => n.id == _notice.id,
        orElse: () => _notice, // Keep the current notice if not found
      );

      if (mounted) {
        setState(() {
          _notice = updatedNotice;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing notice data: $e');
    }
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y h:mm a').format(date);
  }

  // Helper method to format poll expiry dates
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
    final notice = _notice;
    final adminService = _adminService;

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
              _formatDate(notice.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: widget.onEdit != null && widget.onDelete != null
                ? PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Post'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete Post',
                          style: TextStyle(color: Colors.red[400]),
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        widget.onEdit?.call();
                      } else if (value == 'delete') {
                        // Call the delete function directly
                        // The parent widget will handle confirmation and loading state
                        widget.onDelete?.call();
                      }
                    },
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

                // Media Gallery (combines image and video)
                if ((notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ||
                    (notice.videoUrl != null && notice.videoUrl!.isNotEmpty)) ...[
                  MediaGalleryWidget(
                    imageUrls: notice.imageUrls,
                    videoUrl: notice.videoUrl,
                    height: 250,
                  ),
                  const SizedBox(height: 12),
                ],

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
                                    .fold(0, (sum, opt) => sum + (opt.voteCount));
                                final percentage = totalVotes > 0
                                    ? (option.voteCount / totalVotes * 100).round()
                                    : 0;
                                final isUserVoted =
                                    adminService.currentUserId != null &&
                                        option.votedBy
                                            .contains(adminService.currentUserId);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isUserVoted
                                        ? const Color(0xFF00C49A).withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isUserVoted
                                          ? const Color(0xFF00C49A)
                                          : Colors.grey.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isUserVoted)
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              margin: const EdgeInsets.only(right: 8),
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
                                                fontWeight: isUserVoted
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isUserVoted
                                                    ? const Color(0xFF00C49A)
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          // View voters button
                                          if (option.votedBy.isNotEmpty)
                                            GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => PollVotersDialog(
                                                    option: option,
                                                    pollQuestion: notice.poll!.question,
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.people_outline,
                                                      size: 12,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${option.votedBy.length}',
                                                      style: TextStyle(
                                                        color: Colors.grey.shade700,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isUserVoted
                                                  ? const Color(0xFF00C49A)
                                                  : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$percentage%',
                                              style: TextStyle(
                                                color: isUserVoted
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
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          Container(
                                            height: 6,
                                            width: MediaQuery.of(context).size.width *
                                                percentage /
                                                100 *
                                                0.7,
                                            decoration: BoxDecoration(
                                              color: isUserVoted
                                                  ? const Color(0xFF00C49A)
                                                  : const Color(0xFF00C49A)
                                                      .withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          final totalVotes = notice.poll!.options
                                              .fold(0, (sum, opt) => sum + opt.voteCount);
                                          if (totalVotes > 0) {
                                            showDialog(
                                              context: context,
                                              builder: (context) => PollAllVotersDialog(
                                                poll: notice.poll!,
                                              ),
                                            );
                                          }
                                        },
                                        child: Row(
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
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 20, color: Color(0xFF00C49A)),
                                              SizedBox(width: 8),
                                              Text('Poll End Date'),
                                            ],
                                          ),
                                          content: Text(
                                            DateFormat('MMMM d, y h:mm a').format(
                                                notice.poll!.expiresAt.toLocal()),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Close',
                                                  style: TextStyle(
                                                      color: Color(0xFF00C49A))),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color:
                                            const Color(0xFF00C49A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
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
                                            _formatExpiryDate(notice.poll!.expiresAt),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF00C49A),
                                            ),
                                          ),
                                          if (notice.poll!.allowMultipleChoices) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.check_circle_outline,
                                              size: 12,
                                              color: Color(0xFF00C49A),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (notice.poll!.allowMultipleChoices) ...[
                                const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                ] else if (notice.poll != null) ...[
                  Container(
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
                        ...notice.poll!.options.map((option) {
                          final totalVotes = notice.poll!.options
                              .fold(0, (sum, opt) => sum + (opt.voteCount));
                          final percentage = totalVotes > 0
                              ? (option.voteCount / totalVotes * 100).round()
                              : 0;
                          final isUserVoted =
                              adminService.currentUserId != null &&
                                  option.votedBy
                                      .contains(adminService.currentUserId);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isUserVoted
                                  ? const Color(0xFF00C49A).withOpacity(0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUserVoted
                                    ? const Color(0xFF00C49A)
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isUserVoted)
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        margin: const EdgeInsets.only(right: 8),
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
                                          fontWeight: isUserVoted
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isUserVoted
                                              ? const Color(0xFF00C49A)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // View voters button
                                    if (option.votedBy.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => PollVotersDialog(
                                              option: option,
                                              pollQuestion: notice.poll!.question,
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.people_outline,
                                                size: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${option.votedBy.length}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isUserVoted
                                            ? const Color(0xFF00C49A)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$percentage%',
                                        style: TextStyle(
                                          color: isUserVoted
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
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    Container(
                                      height: 6,
                                      width: MediaQuery.of(context).size.width *
                                          percentage /
                                          100 *
                                          0.7,
                                      decoration: BoxDecoration(
                                        color: isUserVoted
                                            ? const Color(0xFF00C49A)
                                            : const Color(0xFF00C49A)
                                                .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final totalVotes = notice.poll!.options
                                        .fold(0, (sum, opt) => sum + opt.voteCount);
                                    if (totalVotes > 0) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => PollAllVotersDialog(
                                          poll: notice.poll!,
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
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
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 20, color: Color(0xFF00C49A)),
                                        SizedBox(width: 8),
                                        Text('Poll End Date'),
                                      ],
                                    ),
                                    content: Text(
                                      DateFormat('MMMM d, y h:mm a').format(
                                          notice.poll!.expiresAt.toLocal()),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close',
                                            style: TextStyle(
                                                color: Color(0xFF00C49A))),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF00C49A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
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
                                      _formatExpiryDate(notice.poll!.expiresAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF00C49A),
                                      ),
                                    ),
                                    if (notice.poll!.allowMultipleChoices) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 12,
                                        color: Color(0xFF00C49A),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (notice.poll!.allowMultipleChoices) ...[
                          const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                ],

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
                      ...notice.attachments!.map((attachment) => _AttachmentItem(attachment: attachment)),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    // Call the method to update like status locally
                                    _toggleLike();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('Error updating like: $e')),
                                      );
                                    }
                                  }
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    notice.isLikedBy(
                                            adminService.currentUserId ?? '')
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: notice.isLikedBy(
                                            adminService.currentUserId ?? '')
                                        ? const Color(0xFF00C49A)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
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
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        CommentsSheet(
                                          notice: notice,
                                          onCommentAdded: () {
                                            // Refresh the notice data to get updated comments count
                                            _refreshNoticeData();
                                          },
                                        ),
                                  );
                                  // Don't call onRefresh to avoid full page reload
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
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
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // Implement share functionality
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
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

class _AttachmentItem extends StatefulWidget {
  final FileAttachment attachment;

  const _AttachmentItem({required this.attachment});

  @override
  State<_AttachmentItem> createState() => _AttachmentItemState();
}

class _AttachmentItemState extends State<_AttachmentItem> {
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
    final fileType = widget.attachment.type.toLowerCase();
    final url = widget.attachment.url;
    final fileName = widget.attachment.name;

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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SizedBox(
                  width: 200,
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
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(videoUrl: widget.videoUrl),
            ),
          );
        },
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 50, color: Colors.red),
                SizedBox(height: 8),
                Text('Error loading video. Tap to try again.'),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerPage(videoUrl: widget.videoUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final aspectRatio = _videoPlayerController.value.aspectRatio;

            double targetWidth, targetHeight;

            if (aspectRatio < 1.0) {
              // Portrait video - use a more reasonable height
              targetHeight = constraints.maxWidth * 1.5;
              targetWidth = targetHeight * aspectRatio;

              // Ensure height doesn't get too extreme
              if (targetHeight > 400) {
                targetHeight = 400;
                targetWidth = targetHeight * aspectRatio;
              }
            } else {
              // Landscape video - constrain by width
              targetWidth = constraints.maxWidth;
              targetHeight = targetWidth / aspectRatio;
            }

            return Container(
              width: targetWidth,
              height: targetHeight,
              color: Colors.black, // Add black background to ensure no white letterboxing
              child: Chewie(controller: _chewieController!),
            );
          },
        ),
      ),
    );
  }
}
