import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/notification_model.dart';

class NotificationItem extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final DismissDirection _dismissDirection = DismissDirection.endToStart;

  final Key _dismissibleKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Colors based on theme
    final backgroundColor = widget.notification.read
        ? (isDarkMode ? theme.cardColor : theme.cardColor)
        : (isDarkMode
            ? colorScheme.primary.withOpacity(0.08)
            : colorScheme.primary.withOpacity(0.04));

    final textColor = isDarkMode ? Colors.grey.shade200 : Colors.grey.shade800;

    final timeColor = isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500;

    return Dismissible(
      key: _dismissibleKey,
      direction: _dismissDirection,
      confirmDismiss: (_) {
        // Call onDismiss callback which will show dialog and handle confirmation
        widget.onDismiss();
        // Always return false so the item isn't automatically dismissed
        return Future.value(false);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 26.0,
        ),
      ),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) {
            _animationController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _animationController.reverse(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: widget.notification.read
                  ? null
                  : [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        blurRadius: 8.0,
                        spreadRadius: 0.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Stack(
                children: [
                  // Left accent color strip
                  if (!widget.notification.read) _buildAccentBar(),

                  // Main notification content
                  Padding(
                    padding: EdgeInsets.only(
                      left: widget.notification.read ? 16.0 : 20.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 16.0,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNotificationIcon(),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.notification.title ??
                                            'Notification',
                                        style: TextStyle(
                                          fontWeight: widget.notification.read
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          fontSize: 15.5,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (!widget.notification.read)
                                      Container(
                                        width: 10.0,
                                        height: 10.0,
                                        margin:
                                            const EdgeInsets.only(left: 8.0),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary
                                                  .withOpacity(0.4),
                                              blurRadius: 6.0,
                                              spreadRadius: 0.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  widget.notification.body ?? '',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14.5,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10.0),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14.0,
                                      color: timeColor,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      timeago.format(
                                          widget.notification.createdAt),
                                      style: TextStyle(
                                        color: timeColor,
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        ),
      ),
    );
  }

  // Creates a left accent color strip for unread notifications
  Widget _buildAccentBar() {
    final Color accentColor = _getTypeColor();

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 4.0,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor,
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 4.0,
              spreadRadius: 0.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData iconData;
    Color iconColor;
    Color backgroundColor;

    // Determine icon and color based on notification type
    iconColor = _getTypeColor();
    backgroundColor = iconColor.withOpacity(0.12);

    // Determine icon based on notification type
    switch (widget.notification.type) {
      case 'community_notice':
        iconData = Icons.campaign_rounded;
        break;
      case 'social_interaction':
        iconData = Icons.thumb_up_alt_rounded;
        break;
      case 'marketplace':
        iconData = Icons.shopping_bag_rounded;
        break;
      case 'chat':
        iconData = Icons.chat_rounded;
        break;
      case 'report':
        iconData = Icons.report_problem_rounded;
        break;
      case 'volunteer':
        iconData = Icons.volunteer_activism_rounded;
        break;
      default:
        iconData = Icons.notifications_rounded;
        break;
    }

    return Container(
      width: 44.0,
      height: 44.0,
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 8.0,
            spreadRadius: 0.0,
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24.0,
      ),
    );
  }

  // Helper method to get color based on notification type
  Color _getTypeColor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (widget.notification.type) {
      case 'community_notice':
        return Colors.blue;
      case 'social_interaction':
        return Colors.green;
      case 'marketplace':
        return Colors.orange;
      case 'chat':
        return Colors.purple;
      case 'report':
        return Colors.red;
      case 'volunteer':
        return Colors.teal;
      default:
        return colorScheme.primary;
    }
  }
}
