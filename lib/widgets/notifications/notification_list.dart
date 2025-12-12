import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/admin_service.dart';
import 'notification_item.dart';

class NotificationList extends StatefulWidget {
  final String? filter;
  final bool isAdminView;

  const NotificationList({
    super.key,
    this.filter,
    this.isAdminView = false,
  });

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  final notificationService = NotificationService();
  final adminService = AdminService();
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _readNotifications =
      []; // Store read notifications that were deleted from Firestore
  bool _isLoading = true;
  bool _isInitialLoad = true;
  bool _hasLoadedOnce = false;
  String? _error;
  bool _isAdmin = false;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _statusSubscription; // Listen to status changes
  Set<String> _deletedNotificationIds = {}; // Track deleted notifications
  DateTime? _userCreatedAt; // Track when the user was created to filter old notifications
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.isAdminView) {
      try {
        _isAdmin = await adminService.isCurrentUserAdmin();
        debugPrint('NOTIFICATION DEBUG: User is admin: $_isAdmin');
      } catch (e) {
        debugPrint('NOTIFICATION DEBUG: Error checking admin status: $e');
        _isAdmin = false;
      }
    }

    // Get the user's creation date to filter out notifications created before they joined
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && userData['createdAt'] != null) {
            if (userData['createdAt'] is Timestamp) {
              _userCreatedAt = (userData['createdAt'] as Timestamp).toDate();
            } else if (userData['createdAt'] is DateTime) {
              _userCreatedAt = userData['createdAt'] as DateTime;
            }
            debugPrint('NOTIFICATION DEBUG: User created at: $_userCreatedAt');
          }
        }
      }
    } catch (e) {
      debugPrint('NOTIFICATION DEBUG: Error getting user creation date: $e');
    }

    // Log the current unread notification count for debugging
    try {
      final count = await notificationService.getUnreadNotificationCount();
      debugPrint(
          'NOTIFICATION DEBUG: Current unread notification count: $count');
    } catch (e) {
      debugPrint(
          'NOTIFICATION DEBUG: Error getting unread notification count: $e');
    }

    // Subscribe to community notifications and status changes
    _subscribeToNotifications();
    _subscribeToStatusChanges();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('NOTIFICATION DEBUG: Subscribing to notifications stream');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('NOTIFICATION DEBUG: No authenticated user found');
        return;
      }

      // Subscribe to notification_status for unread notifications
      _notificationSubscription = FirebaseFirestore.instance
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snapshot) async {
          debugPrint(
              'NOTIFICATION DEBUG: Received notification_status snapshot with ${snapshot.docs.length} documents');

          // Get deleted notifications for this user
          final deletedSnapshot = await FirebaseFirestore.instance
              .collection('deleted_notifications')
              .where('userId', isEqualTo: user.uid)
              .get();

          _deletedNotificationIds = deletedSnapshot.docs
              .map((doc) => doc.data()['notificationId'] as String)
              .toSet();

          debugPrint('NOTIFICATION DEBUG: User has ${_deletedNotificationIds.length} deleted notifications');

          final List<NotificationModel> unreadNotifications = [];
          final List<NotificationModel> readNotificationsFromStatus = [];
          final Set<String> processedNotificationIds = {};

          // Process all notifications from notification_status (both read and unread)
          for (final statusDoc in snapshot.docs) {
            try {
              final statusData = statusDoc.data();
              final notificationId = statusData['notificationId'] as String?;
              final communityId = statusData['communityId'] as String?;
              final isRead = statusData['read'] as bool? ?? false;
              
              debugPrint('NOTIFICATION DEBUG: Processing status record ${statusDoc.id}');
              debugPrint('NOTIFICATION DEBUG:   - notificationId: $notificationId');
              debugPrint('NOTIFICATION DEBUG:   - communityId: $communityId');
              debugPrint('NOTIFICATION DEBUG:   - isRead: $isRead');
              
              if (notificationId == null) {
                debugPrint('NOTIFICATION DEBUG: Skipping - no notificationId');
                continue;
              }
              if (_deletedNotificationIds.contains(notificationId)) {
                debugPrint('NOTIFICATION DEBUG: Skipping - notification deleted');
                continue;
              }

              processedNotificationIds.add(notificationId);

              // Determine which collection to query
              final collection = communityId != null
                  ? 'community_notifications'
                  : 'user_notifications';

              debugPrint('NOTIFICATION DEBUG: Querying $collection for $notificationId');

              final notificationDoc = await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(notificationId)
                  .get();

              if (!notificationDoc.exists) {
                debugPrint('NOTIFICATION DEBUG: Notification not found in $collection');
                continue;
              }

              debugPrint('NOTIFICATION DEBUG: Found notification in $collection');

              final data = notificationDoc.data()!;

              final Map<String, dynamic> completeData = {
                ...data,
                'userId': user.uid,
                'statusId': statusDoc.id,
                'notificationId': notificationId,
                'read': isRead, // Use actual read status from the status document
                'source': communityId != null ? 'community' : 'user',
                'communityId': communityId,
              };

              final notification = NotificationModel.fromMap(completeData);

              // Safety check: skip notifications created before user account
              if (_userCreatedAt != null && notification.createdAt.isBefore(_userCreatedAt!)) {
                debugPrint('NOTIFICATION DEBUG: Skipping notification created before user account: ${notification.title}');
                continue;
              }

              if (!notification.isSelfNotification() ||
                  notification.type == 'community_notice' ||
                  notification.type == 'communityNotices' ||
                  notification.type == 'volunteer') {
                // Separate into read and unread lists
                if (isRead) {
                  readNotificationsFromStatus.add(notification);
                } else {
                  unreadNotifications.add(notification);
                }
              }
            } catch (e) {
              debugPrint('NOTIFICATION DEBUG: Error processing notification: $e');
            }
          }

          // Combine read notifications from status with any additional ones
          final List<NotificationModel> readNotifications = [...readNotificationsFromStatus];

          // Fetch recent user notifications
          // Note: We don't use orderBy here to avoid needing a composite index
          // We'll sort in code instead
          final userSnapshot = await FirebaseFirestore.instance
              .collection('user_notifications')
              .where('userId', isEqualTo: user.uid)
              .limit(50)
              .get();

          for (final doc in userSnapshot.docs) {
            try {
              // Skip if already processed
              if (processedNotificationIds.contains(doc.id)) continue;
              // Skip if deleted
              if (_deletedNotificationIds.contains(doc.id)) continue;

              final data = doc.data();
              final Map<String, dynamic> completeData = {
                ...data,
                'userId': user.uid,
                'statusId': doc.id,
                'notificationId': doc.id,
                'read': true, // No status record means it's read
                'source': 'user',
                'communityId': null,
              };

              final notification = NotificationModel.fromMap(completeData);
              readNotifications.add(notification);
            } catch (e) {
              debugPrint('NOTIFICATION DEBUG: Error processing user notification: $e');
            }
          }

          if (_isInitialLoad) {
            await Future.delayed(const Duration(milliseconds: 300));
          }

          setState(() {
            _notifications = unreadNotifications;
            _readNotifications = readNotifications;
            _isLoading = false;
            _isInitialLoad = false;
            _hasLoadedOnce = true;
          });

          debugPrint(
              'NOTIFICATION DEBUG: Processed ${unreadNotifications.length} unread and ${readNotifications.length} read notifications');
        },
        onError: (e) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
            _isInitialLoad = false;
            _hasLoadedOnce = true;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isInitialLoad = false;
        _hasLoadedOnce = true;
      });
    }
  }

  // Subscribe to notification status changes to detect when notifications are marked as read
  void _subscribeToStatusChanges() {
    // No longer needed since we're already listening to notification_status
    // The main subscription handles all changes
  }

  // Refresh notification data without showing loading indicators
  Future<void> _refreshNotificationData() async {
    // No longer needed since the main subscription auto-refreshes
    // This method can be kept empty for compatibility
  }

  Future<void> _refreshNotifications() async {
    // Don't show loading spinner for refresh if we already have data
    if (!_hasLoadedOnce) {
      setState(() {
        _isLoading = true;
      });
    }

    // Cancel existing subscriptions
    await _notificationSubscription?.cancel();
    await _statusSubscription?.cancel();

    // Resubscribe to get fresh data
    _subscribeToNotifications();
    _subscribeToStatusChanges();

    // Only set loading to false if we were showing loading
    if (!_hasLoadedOnce) {
      setState(() {
        _isLoading = false;
      });
    }

    debugPrint(
        'Refreshed notifications: ${_notifications.length} unread, ${_readNotifications.length} read');
  }

  Future<bool> _showDeleteConfirmationDialog(
      BuildContext context, NotificationModel notification) async {
    final theme = Theme.of(context);
    final dialogResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this notification?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.title ?? 'Notification',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return dialogResult ?? false;
  }

  // Helper method to get icon for notification type
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'community_notice':
        return Icons.campaign_rounded;
      case 'social_interaction':
        return Icons.thumb_up_alt_rounded;
      case 'marketplace':
        return Icons.shopping_bag_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'report':
        return Icons.report_problem_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // Helper method to get color for notification type
  Color _getNotificationColor(String? type) {
    switch (type) {
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
        return Colors.grey;
    }
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title skeleton
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Body skeleton
                    Container(
                      height: 14,
                      width: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time skeleton
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text('Error loading notifications'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _refreshNotifications,
              child: const Text('Try Again'),
            )
          ],
        ),
      );
    }

    // Combine unread notifications and read community notifications with deduplication
    final Map<String, NotificationModel> uniqueNotifications = {};

    for (var notification in _notifications) {
      uniqueNotifications[notification.notificationId] = notification;
    }

    for (var notification in _readNotifications) {
      if (!uniqueNotifications.containsKey(notification.notificationId)) {
        uniqueNotifications[notification.notificationId] = notification;
      }
    }

    List<NotificationModel> allNotifications =
        uniqueNotifications.values.toList();

    // Filter notifications based on admin status
    if (widget.isAdminView) {
      // For admin view, only show admin-specific notifications
      allNotifications = allNotifications.where((notification) {
        final bool isAdminNotification = notification.isAdminNotification();

        final bool isSelfNotif = notification.isSelfNotification();

        // Log for debugging
        debugPrint(
            'ADMIN NOTIFICATION FILTER: ${notification.title} - isAdminNotification: $isAdminNotification, isSelfNotification: $isSelfNotif');
        debugPrint('  - Type: ${notification.type}');
        debugPrint('  - Data: ${notification.data}');

        // Skip self-notifications for admins (e.g., "Admin created this community notice")
        if (isSelfNotif) {
          debugPrint('  - Skipping self-notification for admin');
          return false;
        }

        return isAdminNotification;
      }).toList();

      debugPrint(
          'ADMIN NOTIFICATION FILTER: Filtered to ${allNotifications.length} admin notifications');
    } else {
      // For regular user view, filter out admin-specific notifications and self-notifications
      allNotifications = allNotifications.where((notification) {
        // Always include community notices for regular users
        if (notification.type == 'community_notice' ||
            notification.type == 'communityNotices') {
          debugPrint(
              'USER NOTIFICATION FILTER: Including community notice: ${notification.title}');
          return true;
        }

        // Skip admin-specific notifications for regular users
        if (notification.isAdminNotification()) {
          debugPrint(
              'USER NOTIFICATION FILTER: Skipping admin notification: ${notification.title}');
          return false;
        }

        // Skip self-notifications (except community notices which we already handled)
        if (notification.isSelfNotification()) {
          debugPrint(
              'USER NOTIFICATION FILTER: Skipping self-notification: ${notification.title}');
          return false;
        }

        // Keep all other notifications
        debugPrint(
            'USER NOTIFICATION FILTER: Including regular notification: ${notification.title}');
        return true;
      }).toList();

      debugPrint(
          'USER NOTIFICATION FILTER: Filtered to ${allNotifications.length} user notifications');
    }

    // Apply filter if provided
    if (widget.filter != null &&
        widget.filter!.isNotEmpty &&
        widget.filter != 'all') {
      allNotifications = allNotifications.where((notification) {
        switch (widget.filter) {
          case 'unread':
            return !notification.read;
          case 'community':
            return notification.type == 'community_notice' ||
                notification.type == 'communityNotices' ||
                notification.type == 'volunteer';
          case 'social':
            return notification.type == 'social_interaction' ||
                notification.type == 'socialInteractions';
          case 'market':
          case 'marketplace':
            return notification.type == 'marketplace' ||
                notification.type == 'chat';
          case 'reports':
            return notification.type == 'report' ||
                notification.type == 'reports';
          default:
            return true;
        }
      }).toList();
    }

    // Sort notifications by creation date, newest first
    allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_isLoading && _isInitialLoad) {
      return _buildSkeletonLoading();
    }

    if (allNotifications.isEmpty && _hasLoadedOnce && !_isLoading) {
      return RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshNotifications,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 64,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pull down to refresh',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If we're still loading but not initial load, or have no data but haven't loaded once, show skeleton
    if (allNotifications.isEmpty) {
      return _buildSkeletonLoading();
    }

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _refreshNotifications,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: allNotifications.length,
        itemBuilder: (context, index) {
          final notification = allNotifications[index];
          return NotificationItem(
            notification: notification,
            onTap: () async {
              debugPrint(
                  'Tapped notification: ${notification.type} - ${notification.title}');

              // Mark notification as read when tapped
              if (!notification.read) {
                final updatedData = await notificationService
                    .markNotificationAsRead(notification.id);
                if (updatedData != null) {
                  // The stream will automatically update since we're listening to community_notifications
                  // and checking notification_status for read state. No manual state update needed.
                  debugPrint('Notification marked as read: ${notification.id}');
                }
              }

              // This would typically navigate to the appropriate screen
              debugPrint('Notification tapped: ${notification.id}');
            },
            onDismiss: () async {
              // Capture scaffold messenger early to avoid async gap issues
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final shouldDelete =
                  await _showDeleteConfirmationDialog(context, notification);

              // If user confirmed deletion, proceed with deletion
              if (shouldDelete) {
                // Pass both notificationId and statusId to deleteNotification
                await notificationService.deleteNotification(
                  notification.notificationId,
                  notification.id,
                  isRead: notification.read,
                );

                // Immediately update the local state to remove the notification
                if (mounted) {
                  setState(() {
                    // Add to deleted set
                    _deletedNotificationIds.add(notification.notificationId);
                    
                    // Remove from local lists immediately for instant UI update
                    _notifications.removeWhere(
                      (n) => n.notificationId == notification.notificationId
                    );
                    _readNotifications.removeWhere(
                      (n) => n.notificationId == notification.notificationId
                    );
                  });

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Notification removed'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } else {
                // User canceled, so we need to restore the item in the list
                // This is needed because Dismissible already removed it visually
                setState(() {});
              }
            },
          );
        },
      ),
    );
  }
}
