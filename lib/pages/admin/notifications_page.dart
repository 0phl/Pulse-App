import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/notifications/notification_list.dart';
import '../../widgets/admin_scaffold.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
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
    return AdminScaffold(
      title: 'Notifications',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.pushNamed(context, '/admin/notification-settings');
          },
          tooltip: 'Notification Settings',
        ),
      ],
      body: const NotificationList(),
    );
  }
}
