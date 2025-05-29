import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/admin_service.dart';
import 'notification_item.dart';

class NotificationList extends StatefulWidget {
  // Add a key parameter to force rebuild when needed
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
  bool _isInitialLoad = true; // Track if this is the first load
  bool _hasLoadedOnce = false; // Track if we've loaded data at least once
  String? _error;
  bool _isAdmin = false;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _statusSubscription; // Listen to status changes
  String? _communityId;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if the current user is an admin
    if (widget.isAdminView) {
      try {
        _isAdmin = await adminService.isCurrentUserAdmin();
        debugPrint('NOTIFICATION DEBUG: User is admin: $_isAdmin');
      } catch (e) {
        debugPrint('NOTIFICATION DEBUG: Error checking admin status: $e');
        _isAdmin = false;
      }
    }

    // Get the user's community ID
    _communityId = await notificationService.getUserCommunityId();

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
      debugPrint('NOTIFICATION DEBUG: Subscribing to community notifications stream');

      // Subscribe to community_notifications as the main source
      _notificationSubscription = FirebaseFirestore.instance
          .collection('community_notifications')
          .where('communityId', isEqualTo: _communityId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) async {
          debugPrint(
              'NOTIFICATION DEBUG: Received community notifications snapshot with ${snapshot.docs.length} documents');

          if (!snapshot.docs.isNotEmpty) {
            debugPrint(
                'NOTIFICATION DEBUG: No community notifications found in snapshot');

            // Add a small delay for initial load to prevent flash
            if (_isInitialLoad) {
              await Future.delayed(const Duration(milliseconds: 300));
            }

            setState(() {
              _notifications = [];
              _readNotifications = [];
              _isLoading = false;
              _isInitialLoad = false;
              _hasLoadedOnce = true;
            });
            return;
          }

          // Get current user
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            debugPrint('NOTIFICATION DEBUG: No authenticated user found');
            return;
          }

          // Get all notification status records for this user to check read status
          final statusSnapshot = await FirebaseFirestore.instance
              .collection('notification_status')
              .where('userId', isEqualTo: user.uid)
              .where('communityId', isEqualTo: _communityId)
              .get();

          // Create a map of notification IDs to their read status
          final Map<String, bool> readStatusMap = {};
          for (final statusDoc in statusSnapshot.docs) {
            final data = statusDoc.data();
            final notificationId = data['notificationId'] as String?;
            if (notificationId != null) {
              // If status record exists, notification is unread (false)
              // If no status record exists, notification is considered read (true)
              readStatusMap[notificationId] = false;
            }
          }

          // Process notifications
          final List<NotificationModel> unreadNotifications = [];
          final List<NotificationModel> readNotifications = [];

          for (final doc in snapshot.docs) {
            try {
              debugPrint(
                  'NOTIFICATION DEBUG: Processing community notification: ${doc.id}');

              final data = doc.data();

              // Check if this notification has a status record (unread) or not (read)
              final isRead = !readStatusMap.containsKey(doc.id);

              // Find the status document ID if it exists
              String? statusId;
              if (!isRead) {
                for (final statusDoc in statusSnapshot.docs) {
                  final statusData = statusDoc.data();
                  if (statusData['notificationId'] == doc.id) {
                    statusId = statusDoc.id;
                    break;
                  }
                }
              }

              // Create notification model
              final Map<String, dynamic> completeData = {
                ...data,
                'userId': user.uid,
                'statusId': statusId ?? doc.id, // Use notification ID if no status ID
                'notificationId': doc.id,
                'read': isRead,
                'source': 'community',
                'communityId': _communityId,
              };

              final notification = NotificationModel.fromMap(completeData);

              // Log notification details for debugging
              debugPrint(
                  'NOTIFICATION DEBUG: Processed notification: ${notification.title}');
              debugPrint(
                  'NOTIFICATION DEBUG:   - Read: ${notification.read}');

              // Skip self-notifications unless it's a community notice
              if (!notification.isSelfNotification() ||
                  notification.type == 'community_notice' ||
                  notification.type == 'communityNotices' ||
                  notification.type == 'volunteer') {
                if (notification.read) {
                  readNotifications.add(notification);
                } else {
                  unreadNotifications.add(notification);
                }
              } else {
                debugPrint(
                    'NOTIFICATION DEBUG: Skipping self-notification: ${notification.title}');
              }
            } catch (e) {
              debugPrint('NOTIFICATION DEBUG: Error processing notification: $e');
            }
          }

          // Add a small delay for initial load to prevent flash
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
    if (_communityId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      debugPrint('NOTIFICATION DEBUG: Subscribing to notification status changes');

      _statusSubscription = FirebaseFirestore.instance
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('communityId', isEqualTo: _communityId)
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint('NOTIFICATION DEBUG: Status changes detected, refreshing notifications');
          // When status changes (records added/deleted), refresh the main notification stream
          _refreshNotificationData();
        },
        onError: (e) {
          debugPrint('NOTIFICATION DEBUG: Error in status subscription: $e');
        },
      );
    } catch (e) {
      debugPrint('NOTIFICATION DEBUG: Error setting up status subscription: $e');
    }
  }

  // Refresh notification data without showing loading indicators
  Future<void> _refreshNotificationData() async {
    if (_communityId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current community notifications
      final notificationSnapshot = await FirebaseFirestore.instance
          .collection('community_notifications')
          .where('communityId', isEqualTo: _communityId)
          .orderBy('createdAt', descending: true)
          .get();

      // Get current status records
      final statusSnapshot = await FirebaseFirestore.instance
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('communityId', isEqualTo: _communityId)
          .get();

      // Create a map of notification IDs to their read status
      final Map<String, bool> readStatusMap = {};
      for (final statusDoc in statusSnapshot.docs) {
        final data = statusDoc.data();
        final notificationId = data['notificationId'] as String?;
        if (notificationId != null) {
          readStatusMap[notificationId] = false; // Has status record = unread
        }
      }

      // Process notifications
      final List<NotificationModel> unreadNotifications = [];
      final List<NotificationModel> readNotifications = [];

      for (final doc in notificationSnapshot.docs) {
        try {
          final data = doc.data();
          final isRead = !readStatusMap.containsKey(doc.id);

          // Find the status document ID if it exists
          String? statusId;
          if (!isRead) {
            for (final statusDoc in statusSnapshot.docs) {
              final statusData = statusDoc.data();
              if (statusData['notificationId'] == doc.id) {
                statusId = statusDoc.id;
                break;
              }
            }
          }

          // Create notification model
          final Map<String, dynamic> completeData = {
            ...data,
            'userId': user.uid,
            'statusId': statusId ?? doc.id,
            'notificationId': doc.id,
            'read': isRead,
            'source': 'community',
            'communityId': _communityId,
          };

          final notification = NotificationModel.fromMap(completeData);

          // Skip self-notifications unless it's a community notice
          if (!notification.isSelfNotification() ||
              notification.type == 'community_notice' ||
              notification.type == 'communityNotices' ||
              notification.type == 'volunteer') {
            if (notification.read) {
              readNotifications.add(notification);
            } else {
              unreadNotifications.add(notification);
            }
          }
        } catch (e) {
          debugPrint('NOTIFICATION DEBUG: Error processing notification in refresh: $e');
        }
      }

      // Update state
      if (mounted) {
        setState(() {
          _notifications = unreadNotifications;
          _readNotifications = readNotifications;
        });

        debugPrint(
            'NOTIFICATION DEBUG: Refreshed data - ${unreadNotifications.length} unread, ${readNotifications.length} read');
      }
    } catch (e) {
      debugPrint('NOTIFICATION DEBUG: Error refreshing notification data: $e');
    }
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

  // Show a confirmation dialog before deleting a notification
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

    // Return false if dialog was dismissed or user pressed Cancel
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

  // Build skeleton loading widget
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

    // Add unread notifications first
    for (var notification in _notifications) {
      uniqueNotifications[notification.notificationId] = notification;
    }

    // Add read notifications, only if they don't already exist
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
        // Check if this is an admin-specific notification
        final bool isAdminNotification = notification.isAdminNotification();

        // Check if this is a self-notification (admin seeing their own action)
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
          case 'social':
            return notification.type == 'social_interaction';
          case 'community':
            return notification.type == 'community_notice';
          case 'marketplace':
            return notification.type == 'marketplace';
          default:
            return true;
        }
      }).toList();
    }

    // Sort notifications by creation date, newest first
    allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Show skeleton loading only during initial load AND when we're still loading
    if (_isLoading && _isInitialLoad) {
      return _buildSkeletonLoading();
    }

    // Show empty state if we've loaded at least once and there's no data
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

              // Handle tap based on notification type
              // This would typically navigate to the appropriate screen
              debugPrint('Notification tapped: ${notification.id}');
            },
            onDismiss: () async {
              // Capture scaffold messenger early to avoid async gap issues
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Show confirmation dialog before deleting
              final shouldDelete =
                  await _showDeleteConfirmationDialog(context, notification);

              // If user confirmed deletion, proceed with deletion
              if (shouldDelete) {
                // Delete from the database - this will automatically update the stream
                notificationService.deleteNotification(notification.id);

                // Show snackbar
                if (mounted) {
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
