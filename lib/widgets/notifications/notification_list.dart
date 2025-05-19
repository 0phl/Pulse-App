import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import 'notification_item.dart';

class NotificationList extends StatefulWidget {
  // Add a key parameter to force rebuild when needed
  final String? filter;

  const NotificationList({
    super.key,
    this.filter,
  });

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  final notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _readNotifications =
      []; // Store read notifications that were deleted from Firestore
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _notificationSubscription;
  String? _communityId;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
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

    // Subscribe to unread notifications
    _subscribeToNotifications();

    // Load community notifications if we have a community ID
    if (_communityId != null) {
      _loadCommunityNotifications();
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('NOTIFICATION DEBUG: Subscribing to notifications stream');

      // Subscribe to the notifications stream
      _notificationSubscription =
          notificationService.getUserNotifications().listen(
        (snapshot) async {
          debugPrint(
              'NOTIFICATION DEBUG: Received notification snapshot with ${snapshot.docs.length} documents');

          if (!snapshot.docs.isNotEmpty) {
            debugPrint(
                'NOTIFICATION DEBUG: No notifications found in snapshot');
            setState(() {
              _notifications = [];
              _isLoading = false;
            });
            return;
          }

          // Process notifications in batches to avoid loading too many at once
          final List<NotificationModel> loadedNotifications = [];

          // Log the raw notification status documents for debugging
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint(
                'NOTIFICATION DEBUG: Raw notification status document: ${doc.id}');
            debugPrint(
                'NOTIFICATION DEBUG:   - userId: ${data['userId'] ?? 'null'}');
            debugPrint(
                'NOTIFICATION DEBUG:   - notificationId: ${data['notificationId'] ?? 'null'}');
            debugPrint(
                'NOTIFICATION DEBUG:   - read: ${data['read'] ?? 'null'}');
            debugPrint(
                'NOTIFICATION DEBUG:   - communityId: ${data['communityId'] ?? 'null'}');
          }

          for (final doc in snapshot.docs) {
            try {
              debugPrint(
                  'NOTIFICATION DEBUG: Loading notification from status doc: ${doc.id}');
              final notification = await NotificationModel.fromStatusDoc(doc);

              if (notification != null) {
                // Log notification details for debugging
                debugPrint(
                    'NOTIFICATION DEBUG: Loaded notification: ${notification.title}');
                debugPrint(
                    'NOTIFICATION DEBUG:   - Body: ${notification.body}');
                debugPrint(
                    'NOTIFICATION DEBUG:   - Type: ${notification.type}');
                debugPrint(
                    'NOTIFICATION DEBUG:   - Data: ${notification.data}');
                debugPrint(
                    'NOTIFICATION DEBUG:   - Read: ${notification.read}');
                debugPrint('NOTIFICATION DEBUG:   - ID: ${notification.id}');
                debugPrint(
                    'NOTIFICATION DEBUG:   - NotificationID: ${notification.notificationId}');

                // Skip self-notifications (where the user is seeing their own action)
                if (!notification.isSelfNotification()) {
                  debugPrint(
                      'NOTIFICATION DEBUG:   - Adding notification to list');
                  loadedNotifications.add(notification);
                } else {
                  debugPrint(
                      'NOTIFICATION DEBUG:   - Skipping self-notification: ${notification.title}');
                  // Delete self-notifications to clean up the database
                  notificationService.deleteNotification(notification.id);
                }
              } else {
                debugPrint(
                    'NOTIFICATION DEBUG:   - Notification is null, could not load from status doc');
              }
            } catch (e) {
              debugPrint('NOTIFICATION DEBUG: Error loading notification: $e');
            }
          }

          debugPrint(
              'NOTIFICATION DEBUG: Loaded ${loadedNotifications.length} notifications');

          setState(() {
            _notifications = loadedNotifications;
            _isLoading = false;
          });
        },
        onError: (e) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Load community notifications from Firestore
  Future<void> _loadCommunityNotifications() async {
    if (_communityId == null) return;

    try {
      // Get community notifications
      final notificationData = await notificationService
          .getCommunityNotifications(_communityId!, limit: 50);

      if (notificationData.isNotEmpty) {
        debugPrint('Loaded ${notificationData.length} community notifications');

        // Convert to NotificationModel objects and filter out self-notifications
        final communityNotifications = notificationData
            .map((data) {
              // Add required fields for NotificationModel
              final Map<String, dynamic> completeData = {
                ...data,
                'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                'statusId': data[
                    'notificationId'], // Use notification ID as status ID for read notifications
                'read': true, // Assume read since we're fetching directly
                'source': 'community',
              };

              return NotificationModel.fromMap(completeData);
            })
            .where((notification) => !notification
                .isSelfNotification()) // Filter out self-notifications
            .toList();

        debugPrint(
            'Loaded ${communityNotifications.length} community notifications after filtering out self-notifications');

        // Add to read notifications list
        setState(() {
          _readNotifications = communityNotifications;
          debugPrint(
              'Updated read notifications list with ${_readNotifications.length} items');
        });
      } else {
        debugPrint(
            'No community notifications found for community $_communityId');
      }
    } catch (e) {
      debugPrint('Error loading community notifications: $e');
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });

    // Cancel existing subscription
    await _notificationSubscription?.cancel();

    // Resubscribe to get fresh data
    _subscribeToNotifications();

    // Reload community notifications
    if (_communityId != null) {
      await _loadCommunityNotifications();
    }

    setState(() {
      _isLoading = false;
    });

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
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Error loading notifications'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _refreshNotifications,
              child: const Text('Try Again'),
            )
          ],
        ),
      );
    }

    // Combine unread notifications and read community notifications
    List<NotificationModel> allNotifications = [
      ..._notifications,
      ..._readNotifications
    ];

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

    if (allNotifications.isEmpty) {
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
                      color: Colors.grey.withOpacity(0.5),
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
            onTap: () {
              // Mark notification as read when tapped
              if (!notification.read) {
                notificationService.markNotificationAsRead(notification.id);
              }

              // Handle tap based on notification type
              // This would typically navigate to the appropriate screen
              debugPrint('Notification tapped: ${notification.id}');
            },
            onDismiss: () async {
              // Show confirmation dialog before deleting
              final shouldDelete =
                  await _showDeleteConfirmationDialog(context, notification);

              // If user confirmed deletion, proceed with deletion
              if (shouldDelete) {
                // Delete notification from the list
                setState(() {
                  if (_notifications.contains(notification)) {
                    _notifications.remove(notification);
                  } else if (_readNotifications.contains(notification)) {
                    _readNotifications.remove(notification);
                  }
                });

                // Delete from the database
                notificationService.deleteNotification(notification.id);

                // Show snackbar with undo option
                if (mounted) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Notification removed'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          // Add notification back to the list
                          setState(() {
                            if (notification.read) {
                              _readNotifications.add(notification);
                            } else {
                              _notifications.add(notification);
                            }
                          });
                        },
                      ),
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
