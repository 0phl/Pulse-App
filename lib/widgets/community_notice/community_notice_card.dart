import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/community_notice.dart';
import '../../services/community_notice_service.dart';
import '../media_gallery_widget.dart';
import '../multi_image_viewer_page.dart';
import 'comments_page.dart';
import 'poll_widget.dart';
import 'attachment_widget.dart';
import '../confirmation_dialog.dart';

class CommunityNoticeCard extends StatelessWidget {
  final CommunityNotice notice;
  final bool isAdmin;
  final Function()? onDelete;

  // Static variable to prevent multiple deletion attempts
  static bool _isProcessingDeletion = false;

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
                    onPressed: () async {
                      // Use a static variable to prevent multiple clicks
                      // This ensures we don't trigger multiple deletion attempts
                      if (_isProcessingDeletion) return;

                      try {
                        _isProcessingDeletion = true;

                        // Show confirmation dialog before deleting
                        final shouldDelete = await ConfirmationDialog.show(
                          context: context,
                          title: 'Delete Notice',
                          message: 'Are you sure you want to delete this community notice? This action cannot be undone.',
                          confirmText: 'Delete',
                          cancelText: 'Cancel',
                          confirmColor: Colors.red,
                          icon: Icons.delete_outline,
                          iconBackgroundColor: Colors.red,
                        );

                        // Only proceed with deletion if confirmed
                        if (shouldDelete == true && context.mounted) {
                          // Show deletion in progress
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Deleting notice...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Call the delete function directly and ensure it executes
                          if (onDelete != null) {
                            debugPrint('CommunityNoticeCard: Directly calling delete function');

                            // Call the delete function directly - no need for delays
                            onDelete!();
                            debugPrint('CommunityNoticeCard: Delete function called');
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error deleting notice: $e')),
                          );
                        }
                      } finally {
                        _isProcessingDeletion = false;
                      }
                    },
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await noticeService.likeNotice(
                                    notice.id, user.uid);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
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
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Implement share functionality
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
