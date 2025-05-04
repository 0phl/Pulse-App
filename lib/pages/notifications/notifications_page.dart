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

  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when the page is opened
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    // Mark all as read and get the notification data for community notifications
    final notificationDataList = await _notificationService.markAllNotificationsAsRead();

    // Log the result
    debugPrint('Marked ${notificationDataList.length} notifications as read');

    // The NotificationList widget will handle loading community notifications
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/notification-settings');
            },
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: const NotificationList(),
    );
  }
}
