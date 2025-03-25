import 'package:flutter/material.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import 'comments_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _formatDate(notice.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onEdit != null && onDelete != null)
                            PopupMenuButton(
                              icon: const Icon(Icons.more_vert),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit Post'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Post'),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  onEdit?.call();
                                } else if (value == 'delete') {
                                  onDelete?.call();
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (notice.title.isNotEmpty) ...[
                        Text(
                          notice.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(notice.content),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (notice.imageUrl != null) ...[
            Image.network(
              notice.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${notice.likesCount} likes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${notice.commentsCount} comments',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await adminService.toggleNoticeLike(notice.id);
                        onRefresh?.call();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating like: $e')),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      notice.isLikedBy(adminService.currentUserId ?? '')
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: notice.isLikedBy(adminService.currentUserId ?? '')
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                    label: Text(
                      'Like',
                      style: TextStyle(
                        color:
                            notice.isLikedBy(adminService.currentUserId ?? '')
                                ? Colors.red
                                : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CommentsSheet(notice: notice),
                      );
                      onRefresh?.call();
                    },
                    icon: Icon(
                      Icons.comment_outlined,
                      color: Colors.grey[600],
                    ),
                    label: Text(
                      'Comment',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
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
