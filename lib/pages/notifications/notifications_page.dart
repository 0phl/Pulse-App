import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/notifications/notification_list.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  // Add a key to force rebuild of the NotificationList widget
  final GlobalKey<State<NotificationList>> _notificationListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Don't automatically mark all notifications as read when the page is opened
    // This allows users to see their notifications before they're marked as read

    // Instead, log the current notification count for debugging
    _logNotificationCount();
  }

  Future<void> _logNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadNotificationCount();
      debugPrint('Current unread notification count: $count');
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
    }
  }

  // Show a confirmation dialog for marking all notifications as read
  void _showMarkAllAsReadDialog(BuildContext context) {
    // Show a confirmation dialog
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text('Are you sure you want to mark all notifications as read?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Mark as read immediately when the button is pressed
              _markAllAsReadAndShowSnackbar(context);
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Mark All as Read'),
          ),
        ],
      ),
    );
  }

  // Helper method to mark all as read and show a snackbar
  Future<void> _markAllAsReadAndShowSnackbar(BuildContext context) async {
    // Get the ScaffoldMessengerState before any async operations
    final scaffoldMessengerState = ScaffoldMessenger.of(context);

    // Mark all as read
    final notificationDataList = await _notificationService.markAllNotificationsAsRead();

    // Log the result
    debugPrint('Marked ${notificationDataList.length} notifications as read');

    // Show a snackbar to confirm if the widget is still mounted
    if (mounted) {
      scaffoldMessengerState.showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Add a "Refresh" button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Show a loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing notifications...'),
                  duration: Duration(seconds: 1),
                ),
              );

              // Get the current notification count for debugging
              try {
                final count = await _notificationService.getUnreadNotificationCount();
                debugPrint('Current unread notification count before refresh: $count');
              } catch (e) {
                debugPrint('Error getting unread notification count: $e');
              }

              // Refresh the notification list by recreating it
              setState(() {
                // Create a new key to force a complete rebuild of the NotificationList widget
                _notificationListKey.currentState?.setState(() {});
              });

              // Get the notification count after refresh for debugging
              try {
                final count = await _notificationService.getUnreadNotificationCount();
                debugPrint('Current unread notification count after refresh: $count');
              } catch (e) {
                debugPrint('Error getting unread notification count: $e');
              }
            },
            tooltip: 'Refresh Notifications',
          ),
          // Add a "Mark All as Read" button
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              _showMarkAllAsReadDialog(context);
            },
            tooltip: 'Mark All as Read',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/notification-settings');
            },
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: NotificationList(key: _notificationListKey),
    );
  }
}
