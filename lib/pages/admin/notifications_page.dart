import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/notifications/notification_list.dart';
import '../admin/admin_drawer.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<State<NotificationList>> _notificationListKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isRefreshing = false;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterOptions.length, vsync: this);
    _tabController.addListener(_handleTabChange);
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

    // Force refresh to update the UI
    if (mounted) {
      setState(() {
        _notificationListKey.currentState?.setState(() {});
      });
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

    // Refresh the notification list by recreating it
    if (mounted) {
      setState(() {
        // Create a new key to force a complete rebuild of the NotificationList widget
        _notificationListKey.currentState?.setState(() {});
      });
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
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
              Navigator.pushNamed(context, '/admin/notification-settings');
            },
            tooltip: 'Notification Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AdminDrawer(),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.grey.shade800.withOpacity(0.5)
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
                    ? theme.colorScheme.primary.withOpacity(0.15)
                    : theme.colorScheme.primary.withOpacity(0.1),
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
                          theme.scaffoldBackgroundColor.withOpacity(0.95),
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
                isAdminView: true, // Set to true for admin notifications
              ),
            ),
          ),
        ],
      ),
    );
  }
}
