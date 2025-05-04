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
      final statusData = statusDoc.data() as Map<String, dynamic>;
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Get the notification ID from the status document
      final notificationId = statusData['notificationId'] as String;
      final communityId = statusData['communityId'] as String?;

      // Determine which collection to query based on whether it's a community notification
      final collection = communityId != null ? 'community_notifications' : 'user_notifications';

      // Get the actual notification document
      final notificationDoc = await firestore.collection(collection).doc(notificationId).get();

      if (!notificationDoc.exists) {
        return null;
      }

      final notificationData = notificationDoc.data() as Map<String, dynamic>;

      return NotificationModel(
        id: statusDoc.id, // Status document ID
        notificationId: notificationId, // Notification document ID
        userId: statusData['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        title: notificationData['title'],
        body: notificationData['body'],
        type: notificationData['type'] ?? 'general',
        data: notificationData['data'] ?? {},
        read: statusData['read'] ?? false,
        createdAt: (notificationData['createdAt'] as Timestamp?)?.toDate() ??
                  (statusData['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
        source: communityId != null ? 'community' : 'user',
        communityId: communityId,
      );
    } catch (e) {
      debugPrint('Error creating NotificationModel from status doc: $e');
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
}
