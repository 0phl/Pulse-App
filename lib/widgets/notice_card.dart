import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import 'comments_sheet.dart';
import 'image_gallery_viewer.dart';

class NoticeCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final adminService = AdminService();

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
              _formatDate(notice.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: onEdit != null && onDelete != null
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
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'delete') {
                        onDelete?.call();
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
                // Image Gallery
                if (notice.imageUrls != null && notice.imageUrls!.isNotEmpty) ...[
                  ImageGalleryViewer(
                    imageUrls: notice.imageUrls!,
                    height: 200,
                  ),
                  const SizedBox(height: 12),
                ],

                // Video, Poll, and Attachments are handled in CommunityNoticeCard
                // For this card, we'll just show a placeholder for these media types
                if (notice.videoUrl != null) ...[
                  Container(
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
                          Icon(Icons.play_circle_outline, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Video content available'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (notice.poll != null) ...[
                  Container(
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
                          notice.poll!.question,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...notice.poll!.options.map((option) {
                          final totalVotes = notice.poll!.options.fold(
                              0, (sum, opt) => sum + (opt.voteCount));
                          final percentage = totalVotes > 0
                              ? (option.voteCount / totalVotes * 100).round()
                              : 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option.text,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '$percentage%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: totalVotes > 0
                                      ? option.voteCount / totalVotes
                                      : 0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.how_to_vote_outlined,
                                  size: 14,
                                  color: Colors.grey[600]
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${notice.poll!.options.fold(0, (sum, opt) => sum + opt.voteCount)} votes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Poll End Date'),
                                        content: Text(
                                          DateFormat('MMMM d, y h:mm a').format(notice.poll!.expiresAt.toLocal()),
                                          style: const TextStyle(fontSize: 16),
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
                                  child: Row(
                                    children: [
                                      Icon(Icons.schedule,
                                        size: 14,
                                        color: Colors.grey[600]
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatExpiryDate(notice.poll!.expiresAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (notice.poll!.allowMultipleChoices) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.check_circle_outline,
                                    size: 14,
                                    color: Colors.grey[600]
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Multiple choices',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (notice.attachments != null && notice.attachments!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attachments',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text('${notice.attachments!.length} attachment(s) available'),
                      ],
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
                            try {
                              await adminService.toggleNoticeLike(notice.id);
                              onRefresh?.call();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error updating like: $e')),
                                );
                              }
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                notice.isLikedBy(
                                        adminService.currentUserId ?? '')
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 20,
                                color: notice.isLikedBy(
                                        adminService.currentUserId ?? '')
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
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  CommentsSheet(notice: notice),
                            );
                            onRefresh?.call();
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

  String _formatDate(DateTime date) {
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
