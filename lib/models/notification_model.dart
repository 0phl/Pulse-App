import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationModel {
  final String id; // This is the status document ID
  final String notificationId; // ID of the actual notification document
  final String userId;
  final String? title;
  final String? body;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;
  final String? source; // 'community' or 'user'
  final String? communityId;

  NotificationModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    this.title,
    this.body,
    required this.type,
    required this.data,
    required this.read,
    required this.createdAt,
    this.source,
    this.communityId,
  });

  // Create from Firestore notification status document
  static Future<NotificationModel?> fromStatusDoc(DocumentSnapshot statusDoc) async {
    try {
      debugPrint('NOTIFICATION MODEL DEBUG: Loading notification from status doc: ${statusDoc.id}');
      final statusData = statusDoc.data() as Map<String, dynamic>;
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Get the notification ID from the status document
      final notificationId = statusData['notificationId'] as String;
      final communityId = statusData['communityId'] as String?;
      final read = statusData['read'] ?? false;

      debugPrint('NOTIFICATION MODEL DEBUG: Status data - notificationId: $notificationId, communityId: $communityId, read: $read');

      // Determine which collection to query based on whether it's a community notification
      final collection = communityId != null ? 'community_notifications' : 'user_notifications';
      debugPrint('NOTIFICATION MODEL DEBUG: Looking for notification in collection: $collection');

      // Get the actual notification document
      final notificationDoc = await firestore.collection(collection).doc(notificationId).get();

      if (!notificationDoc.exists) {
        debugPrint('NOTIFICATION MODEL DEBUG: Notification document not found in $collection collection: $notificationId');

        // Try the other collection as a fallback
        final fallbackCollection = communityId != null ? 'user_notifications' : 'community_notifications';
        debugPrint('NOTIFICATION MODEL DEBUG: Trying fallback collection: $fallbackCollection');

        final fallbackDoc = await firestore.collection(fallbackCollection).doc(notificationId).get();

        if (!fallbackDoc.exists) {
          debugPrint('NOTIFICATION MODEL DEBUG: Notification document not found in fallback collection either');
          return null;
        }

        debugPrint('NOTIFICATION MODEL DEBUG: Found notification in fallback collection');
        final notificationData = fallbackDoc.data() as Map<String, dynamic>;

        // Log the notification data for debugging
        debugPrint('NOTIFICATION MODEL DEBUG: Notification data - title: ${notificationData['title']}, type: ${notificationData['type']}');

        return NotificationModel(
          id: statusDoc.id, // Status document ID
          notificationId: notificationId, // Notification document ID
          userId: statusData['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
          title: notificationData['title'],
          body: notificationData['body'],
          type: notificationData['type'] ?? 'general',
          data: notificationData['data'] ?? {},
          read: read,
          createdAt: (notificationData['createdAt'] as Timestamp?)?.toDate() ??
                    (statusData['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
          source: fallbackCollection == 'community_notifications' ? 'community' : 'user',
          communityId: communityId,
        );
      }

      debugPrint('NOTIFICATION MODEL DEBUG: Found notification in primary collection');
      final notificationData = notificationDoc.data() as Map<String, dynamic>;

      // Log the notification data for debugging
      debugPrint('NOTIFICATION MODEL DEBUG: Notification data - title: ${notificationData['title']}, type: ${notificationData['type']}');

      return NotificationModel(
        id: statusDoc.id, // Status document ID
        notificationId: notificationId, // Notification document ID
        userId: statusData['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        title: notificationData['title'],
        body: notificationData['body'],
        type: notificationData['type'] ?? 'general',
        data: notificationData['data'] ?? {},
        read: read,
        createdAt: (notificationData['createdAt'] as Timestamp?)?.toDate() ??
                  (statusData['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
        source: communityId != null ? 'community' : 'user',
        communityId: communityId,
      );
    } catch (e) {
      debugPrint('NOTIFICATION MODEL DEBUG: Error creating NotificationModel from status doc: $e');
      return null;
    }
  }

  // Create from Firestore document (for backward compatibility)
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Check if this is a status document
    if (data.containsKey('notificationId')) {
      // This is a status document, but we can't load the actual notification here
      // because this is a synchronous factory method
      return NotificationModel(
        id: doc.id,
        notificationId: data['notificationId'] ?? '',
        userId: data['userId'] ?? '',
        title: null, // Will be loaded later
        body: null, // Will be loaded later
        type: 'general',
        data: {},
        read: data['read'] ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: data['communityId'] != null ? 'community' : 'user',
        communityId: data['communityId'],
      );
    } else {
      // This is an old-style notification document
      return NotificationModel(
        id: doc.id,
        notificationId: doc.id, // Same as ID for old-style notifications
        userId: data['userId'] ?? '',
        title: data['title'],
        body: data['body'],
        type: data['type'] ?? 'general',
        data: data['data'] ?? {},
        read: data['read'] ?? false,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: 'user', // Default for old-style notifications
        communityId: null,
      );
    }
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source,
      'communityId': communityId,
    };
  }

  // Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? notificationId,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
    String? source,
    String? communityId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      communityId: communityId ?? this.communityId,
    );
  }

  // Create from a Map (useful for creating from combined data)
  static NotificationModel fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['statusId'] ?? map['id'] ?? '',
      notificationId: map['notificationId'] ?? '',
      userId: map['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
      title: map['title'],
      body: map['body'],
      type: map['type'] ?? 'general',
      data: map['data'] ?? {},
      read: map['read'] ?? false,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is DateTime ? map['createdAt'] : DateTime.now()),
      source: map['communityId'] != null ? 'community' : 'user',
      communityId: map['communityId'],
    );
  }

  // Check if this notification is relevant for admins
  bool isAdminNotification() {
    // Check if the notification type is admin-specific
    if (type == 'admin_notification' ||
        type == 'admin_test' ||
        type.startsWith('admin_')) {
      return true;
    }

    // Check if the notification data indicates it's for admins
    if (data.containsKey('isForAdmin') &&
        (data['isForAdmin'] == true || data['isForAdmin'] == 'true')) {
      return true;
    }

    // Check if the notification is about admin-specific features
    if (type == 'reports' || type == 'report') {
      return true;
    }

    // Check if the notification is about community management
    if (data.containsKey('adminAction') &&
        (data['adminAction'] == true || data['adminAction'] == 'true')) {
      return true;
    }

    // For community notices, only show admin notifications if they're from the admin's community
    if (type == 'community_notice' || type == 'communityNotices') {
      // If the notification has adminCommunityId field, check if it matches
      if (data.containsKey('adminCommunityId')) {
        return true;
      }

      // If the notification is about community management
      if (data.containsKey('isAdminNotice') &&
          (data['isAdminNotice'] == true || data['isAdminNotice'] == 'true')) {
        return true;
      }

      // If the notification is from an admin
      if (data.containsKey('authorIsAdmin') &&
          (data['authorIsAdmin'] == true || data['authorIsAdmin'] == 'true')) {
        return true;
      }
    }

    // Check if this is a social interaction related to admin content
    if (type == 'social_interaction' || type == 'socialInteractions') {
      // If the notification is about admin content
      if (data.containsKey('targetIsAdmin') &&
          (data['targetIsAdmin'] == true || data['targetIsAdmin'] == 'true')) {
        return true;
      }

      // If the notification is about admin actions
      if (data.containsKey('adminAction') &&
          (data['adminAction'] == true || data['adminAction'] == 'true')) {
        return true;
      }

      // If the notification is about admin content
      if (body != null && body!.toLowerCase().contains('admin')) {
        return true;
      }
    }

    // By default, most notifications are not admin-specific
    return false;
  }

  // Check if this notification is a self-notification (user is seeing their own action)
  bool isSelfNotification() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    // For social interactions, check if the user is the one who performed the action
    if (type == 'socialInteractions' || type == 'social_interaction') {
      // IMPORTANT: Notifications about someone liking YOUR content are NOT self-notifications
      // These should be shown to you, as they're actions others took on your content

      // Check for likes - if the current user is the liker (you liked someone else's content)
      if (data.containsKey('likerId') && data['likerId'] == currentUserId) {
        debugPrint('SELF-NOTIFICATION: You liked someone else\'s content');
        return true;
      }

      // Check for comments/replies - if the current user is the author (you commented on someone else's content)
      if (data.containsKey('authorId') && data['authorId'] == currentUserId &&
          !(data.containsKey('targetUserId') && data['targetUserId'] == currentUserId)) {
        debugPrint('SELF-NOTIFICATION: You commented on someone else\'s content');
        return true;
      }

      // Check for mentions - if the current user is the one who mentioned someone
      if (data.containsKey('mentionedBy') && data['mentionedBy'] == currentUserId) {
        debugPrint('SELF-NOTIFICATION: You mentioned someone');
        return true;
      }

      // Additional check for the notification body text
      // This handles cases where the notification data structure might not have the expected fields
      if (body != null) {
        final bodyText = body!.toLowerCase();

        // IMPORTANT: Messages like "X liked your comment" are NOT self-notifications
        // These should be shown to the user as they're notifications about actions on their content
        if (bodyText.contains(' liked your ') ||
            bodyText.contains(' replied to your ') ||
            bodyText.contains(' mentioned you ')) {
          debugPrint('NOT a self-notification: Someone interacted with your content: $body');
          return false;
        }

        // Special case for the specific format "Zaki Tolentino liked your comment: "hi""
        if (bodyText.contains(' liked your comment:') ||
            bodyText.contains(' liked your reply:') ||
            bodyText.contains(' liked your post:') ||
            bodyText.contains('likedyourcomment:') || // Handle cases without spaces
            bodyText.contains('likedyourreply:') ||
            bodyText.contains('likedyourpost:')) {
          debugPrint('NOT a self-notification: Someone liked your content with quote: $body');
          return false;
        }

        // Final fallback check - if the notification contains both another user's name and "your",
        // it's likely about someone else's action on your content
        if (bodyText.contains(' your ') && !bodyText.startsWith(FirebaseAuth.instance.currentUser?.displayName?.toLowerCase() ?? '')) {
          debugPrint('NOT a self-notification (fallback check): $body');
          return false;
        }

        // Get the actor name (the person who performed the action)
        String? actorName;
        if (bodyText.contains(' liked ') || bodyText.contains(' replied ') || bodyText.contains(' mentioned ')) {
          final parts = body!.split(' ');
          actorName = parts.isNotEmpty ? parts.first : null;
        }

        // Check if YOU are the actor (the person who performed the action)
        if (actorName != null && actorName.isNotEmpty) {
          // If the notification starts with your name and doesn't contain "your",
          // it's likely about an action YOU performed on someone else's content
          if (bodyText.startsWith(actorName.toLowerCase()) &&
              !bodyText.contains(' your ') &&
              !bodyText.contains(' you ')) {
            debugPrint('SELF-NOTIFICATION: You performed an action: $body');
            return true;
          }
        }
      }
    }

    return false;
  }
}
