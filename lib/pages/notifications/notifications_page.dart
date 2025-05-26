import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/notifications/notification_list.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  // Add a key to force rebuild of the NotificationList widget
  final GlobalKey<State<NotificationList>> _notificationListKey = GlobalKey();

  // For filter tabs
  late TabController _tabController;
  final List<String> _filterOptions = [
    'All',
    'Unread',
    'Social',
    'Community',
    'Marketplace'
  ];
  String _currentFilter = 'All';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterOptions.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Log the current notification count for debugging
    _logNotificationCount();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentFilter = _filterOptions[_tabController.index];
      });
    }
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
        content: const Text(
            'Are you sure you want to mark all notifications as read?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
    final notificationDataList =
        await _notificationService.markAllNotificationsAsRead();

    // Log the result
    debugPrint('Marked ${notificationDataList.length} notifications as read');

    // Show a snackbar to confirm if the widget is still mounted
    if (mounted) {
      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('All notifications marked as read'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Refreshing notifications...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
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
    if (mounted) {
      setState(() {
        // Create a new key to force a complete rebuild of the NotificationList widget
        _notificationListKey.currentState?.setState(() {});
      });
    }

    // Get the notification count after refresh for debugging
    try {
      final count = await _notificationService.getUnreadNotificationCount();
      debugPrint('Current unread notification count after refresh: $count');
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
    }

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // Add a "Refresh" button
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: primaryColor,
                    ),
            ),
            onPressed: _isRefreshing ? null : _refreshNotifications,
            tooltip: 'Refresh Notifications',
          ),
          // Add a "Mark All as Read" button
          IconButton(
            icon: Icon(
              Icons.done_all_rounded,
              color: primaryColor,
            ),
            onPressed: () {
              _showMarkAllAsReadDialog(context);
            },
            tooltip: 'Mark All as Read',
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: primaryColor,
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/notification-settings');
            },
            tooltip: 'Notification Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDarkMode
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: _filterOptions
                  .map((filter) => Tab(
                        text: filter,
                        height: 36,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.grey.shade50,
                          Colors.white,
                        ],
                      ),
              ),
              child: NotificationList(
                key: _notificationListKey,
                filter: _currentFilter.toLowerCase(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
