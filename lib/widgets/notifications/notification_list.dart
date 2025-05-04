import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import 'notification_item.dart';

class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  final notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _readNotifications = []; // Store read notifications that were deleted from Firestore
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _notificationSubscription;
  String? _communityId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Get the user's community ID
    _communityId = await notificationService.getUserCommunityId();

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
      // Subscribe to the notifications stream
      _notificationSubscription = notificationService.getUserNotifications().listen(
        (snapshot) async {
          if (!snapshot.docs.isNotEmpty) {
            setState(() {
              _notifications = [];
              _isLoading = false;
            });
            return;
          }

          // Process notifications in batches to avoid loading too many at once
          final List<NotificationModel> loadedNotifications = [];

          for (final doc in snapshot.docs) {
            try {
              final notification = await NotificationModel.fromStatusDoc(doc);
              if (notification != null) {
                loadedNotifications.add(notification);
              }
            } catch (e) {
              debugPrint('Error loading notification: $e');
            }
          }

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
      final notificationData = await notificationService.getCommunityNotifications(_communityId!, limit: 50);

      if (notificationData.isNotEmpty) {
        debugPrint('Loaded ${notificationData.length} community notifications');

        // Convert to NotificationModel objects
        final communityNotifications = notificationData
            .map((data) {
              // Add required fields for NotificationModel
              final Map<String, dynamic> completeData = {
                ...data,
                'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                'statusId': data['notificationId'], // Use notification ID as status ID for read notifications
                'read': true, // Assume read since we're fetching directly
                'source': 'community',
              };

              return NotificationModel.fromMap(completeData);
            })
            .toList();

        // Add to read notifications list
        setState(() {
          _readNotifications = communityNotifications;
          debugPrint('Updated read notifications list with ${_readNotifications.length} items');
        });
      } else {
        debugPrint('No community notifications found for community $_communityId');
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

    debugPrint('Refreshed notifications: ${_notifications.length} unread, ${_readNotifications.length} read');
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
        child: Text('Error: $_error'),
      );
    }

    // Combine unread notifications and read community notifications
    final allNotifications = [..._notifications, ..._readNotifications];

    if (allNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Sort notifications by creation date (newest first)
    allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      onRefresh: () async {
        // Reload notifications
        await _refreshNotifications();
      },
      child: ListView.builder(
        itemCount: allNotifications.length,
        itemBuilder: (context, index) {
          final notification = allNotifications[index];
          final isFromStatusCollection = _notifications.contains(notification);

          return NotificationItem(
            notification: notification,
            onTap: () {
              // Create a local copy of the notification to use after async operations
              final currentNotification = notification;

              // Handle the notification tap
              _handleNotificationTap(context, currentNotification);

              // Mark as read in a separate async function
              if (isFromStatusCollection) {
                _markNotificationAsRead(currentNotification);
              }
            },
            onDismiss: () {
              if (isFromStatusCollection) {
                // Delete notification from Firestore
                notificationService.deleteNotification(notification.id);

                // Remove from local list
                setState(() {
                  _notifications.remove(notification);
                });
              } else {
                // Just remove from local list for read notifications
                setState(() {
                  _readNotifications.remove(notification);
                });
              }

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Mark a notification as read and handle the result
  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    // Mark as read in memory first
    setState(() {
      // Find the index in the _notifications list
      final notificationIndex = _notifications.indexOf(notification);
      if (notificationIndex >= 0) {
        // Create a copy with read=true
        _notifications[notificationIndex] = notification.copyWith(read: true);
      }
    });

    // Mark as read in Firestore and get the notification data
    final notificationData = await notificationService.markNotificationAsRead(notification.id);

    if (notificationData != null && mounted) {
      // Add to read notifications list if it's a community notification
      if (notificationData['communityId'] != null) {
        debugPrint('Adding community notification to read list: ${notificationData['title']}');

        // Check if this notification is already in the read notifications list
        final existingIndex = _readNotifications.indexWhere(
          (n) => n.notificationId == notificationData['notificationId']
        );

        setState(() {
          if (existingIndex >= 0) {
            // Update existing notification
            _readNotifications[existingIndex] = NotificationModel.fromMap(notificationData);
            debugPrint('Updated existing notification in read list');
          } else {
            // Add new notification
            _readNotifications.add(NotificationModel.fromMap(notificationData));
            debugPrint('Added new notification to read list');
          }

          // Remove from unread list
          _notifications.removeWhere((n) => n.id == notification.id);
        });
      } else {
        // For non-community notifications, just remove from unread list
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });
      }
    }
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    // Handle notification tap based on type
    switch (notification.type) {
      case 'communityNotices':
      case 'community_notice':
        if (notification.data.containsKey('noticeId')) {
          // Navigate to community notice details
          // String noticeId = notification.data['noticeId'];
          // Navigator.pushNamed(context, '/community-notice-details', arguments: noticeId);
          debugPrint('Navigate to community notice: ${notification.data['noticeId']}');
        }
        break;
      case 'socialInteractions':
      case 'social_interaction':
        if (notification.data.containsKey('noticeId')) {
          // Navigate to community notice details
          // String noticeId = notification.data['noticeId'];
          // Navigator.pushNamed(context, '/community-notice-details', arguments: noticeId);
          debugPrint('Navigate to social interaction: ${notification.data['noticeId']}');
        }
        break;
      case 'marketplace':
        if (notification.data.containsKey('itemId')) {
          // Navigate to marketplace item details
          // String itemId = notification.data['itemId'];
          // Navigator.pushNamed(context, '/marketplace-item-details', arguments: itemId);
          debugPrint('Navigate to marketplace item: ${notification.data['itemId']}');
        }
        break;
      case 'chat':
        if (notification.data.containsKey('chatId')) {
          // Navigate to chat screen
          // String chatId = notification.data['chatId'];
          // Navigator.pushNamed(context, '/chat', arguments: chatId);
          debugPrint('Navigate to chat: ${notification.data['chatId']}');
        }
        break;
      case 'reports':
      case 'report':
        if (notification.data.containsKey('reportId')) {
          // Navigate to report details
          // String reportId = notification.data['reportId'];
          // Navigator.pushNamed(context, '/report-details', arguments: reportId);
          debugPrint('Navigate to report: ${notification.data['reportId']}');
        }
        break;
      case 'volunteer':
        if (notification.data.containsKey('volunteerId')) {
          // Navigate to volunteer post details
          // String volunteerId = notification.data['volunteerId'];
          // Navigator.pushNamed(context, '/volunteer-details', arguments: volunteerId);
          debugPrint('Navigate to volunteer post: ${notification.data['volunteerId']}');
        }
        break;
      default:
        // Default action for general notifications
        debugPrint('Notification type not handled: ${notification.type}');
        break;
    }
  }
}
