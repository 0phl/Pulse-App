import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/notification_model.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();

  debugPrint('==========================================');
  debugPrint('RECEIVED BACKGROUND MESSAGE!');
  debugPrint('Message data: ${message.data}');

  if (message.notification != null) {
    debugPrint('Title: ${message.notification!.title}');
    debugPrint('Body: ${message.notification!.body}');
    debugPrint('==========================================');
  } else {
    debugPrint('No notification payload in the message');
    debugPrint('==========================================');
  }

  // You can perform background tasks here, but keep them lightweight
  // For example, you might want to store the notification in Firestore
  // but avoid heavy processing
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FlutterLocalNotificationsPlugin? _localNotifications;
  AndroidNotificationChannel? _androidChannel;

  bool _initialized = false;
  String? _token;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      await _requestPermission();

      // Configure FCM handlers
      _configureForegroundMessageHandler();
      _configureBackgroundMessageHandler();
      _configureMessageOpenedAppHandler();

      // Get and save FCM token
      await _getAndSaveToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen(_updateToken);

      // Ensure user_tokens document exists
      await _ensureUserTokensDocumentExists();

      // Clean up read notifications to save storage space
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await cleanupReadNotifications();
        } catch (e) {
          debugPrint('Warning: Could not clean up read notifications: $e');
        }
      }

      // Try to set up local notifications, but don't fail if it doesn't work
      try {
        await _setupLocalNotifications();
      } catch (e) {
        debugPrint('Warning: Could not set up local notifications: $e');
        debugPrint('Push notifications may still work, but foreground notifications might not show');
      }

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      // Still mark as initialized to prevent repeated initialization attempts
      _initialized = true;
    }
  }

  // Ensure user_tokens document exists
  Future<void> _ensureUserTokensDocumentExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Cannot ensure user_tokens document: User not logged in');
      return;
    }

    try {
      debugPrint('Checking if user_tokens document exists for user: ${user.uid}');
      final docSnapshot = await _firestore.collection('user_tokens').doc(user.uid).get();

      if (!docSnapshot.exists) {
        debugPrint('User_tokens document does not exist, creating default document');
        // Create default document
        await _firestore.collection('user_tokens').doc(user.uid).set({
          'notificationPreferences': {
            'communityNotices': true,
            'socialInteractions': true,
            'marketplace': true,
            'chat': true,
            'reports': true,
            'volunteer': true,
          },
          'tokens': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Created user_tokens document for user: ${user.uid}');
      } else {
        debugPrint('User_tokens document already exists for user: ${user.uid}');
        final data = docSnapshot.data();
        if (data != null) {
          // Check if notificationPreferences exists
          if (!data.containsKey('notificationPreferences')) {
            debugPrint('notificationPreferences field missing, adding default preferences');
            await _firestore.collection('user_tokens').doc(user.uid).update({
              'notificationPreferences': {
                'communityNotices': true,
                'socialInteractions': true,
                'marketplace': true,
                'chat': true,
                'reports': true,
                'volunteer': true,
              },
            });
            debugPrint('Added default notification preferences');
          }

          final tokens = data['tokens'] as List<dynamic>? ?? [];
          debugPrint('Current tokens count: ${tokens.length}');

          // Check if tokens field is properly initialized
          if (tokens.isEmpty) {
            debugPrint('Tokens array is empty');
          } else {
            debugPrint('Tokens array contains ${tokens.length} entries');
          }
        }
      }
    } catch (e) {
      debugPrint('Error ensuring user_tokens document exists: $e');
      debugPrint(e.toString());
    }
  }

  // Request notification permission
  Future<void> _requestPermission() async {
    try {
      debugPrint('Requesting notification permission...');

      // For all platforms, use Firebase Messaging to request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      // Check if permission was granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission');
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      debugPrint(e.toString());
      // Continue anyway, as the app might still receive notifications
    }
  }

  // Setup local notifications for foreground messages
  Future<void> _setupLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Android initialization
    // For older versions of flutter_local_notifications, we use a different approach
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
      description: 'This channel is used for important notifications.',
    );

    // Create the Android notification channel
    await _localNotifications!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _androidChannel = channel;

    // Initialize settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notification_icon');

    // For newer versions, we use DarwinInitializationSettings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // For newer versions, we use a different callback approach
    await _localNotifications!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');

        // You can navigate to a specific screen based on the payload
        // For example, if the payload is a JSON string containing route information
        if (response.payload != null) {
          // Parse the payload and navigate accordingly
          // Example: Navigator.pushNamed(context, payload['route'], arguments: payload['data']);
        }
      },
    );

    debugPrint('Local notifications setup complete');
  }

  // Configure foreground message handler with optimized handling
  void _configureForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('==========================================');
      debugPrint('RECEIVED FOREGROUND MESSAGE! ${DateTime.now().toIso8601String()}');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Title: ${message.notification!.title}');
        debugPrint('Body: ${message.notification!.body}');
        debugPrint('Android: ${message.notification!.android?.toString()}');
        debugPrint('Apple: ${message.notification!.apple?.toString()}');
        debugPrint('==========================================');

        // Process high-priority notifications immediately
        if (message.data['priority'] == 'high' ||
            message.data['type'] == 'chat' ||
            message.data['type'] == 'communityNotices') {
          // Show notification immediately for high-priority messages
          await _showLocalNotification(message);
        } else {
          // For normal priority, still show quickly but allow for batching
          _showLocalNotification(message);
        }
      } else {
        debugPrint('No notification payload in the message');
        debugPrint('==========================================');

        // Even without notification payload, we should process data messages
        _processDataMessage(message);
      }
    });

    debugPrint('Optimized foreground message handler configured');
  }

  // Process data-only messages
  void _processDataMessage(RemoteMessage message) {
    // Handle data-only messages (no visible notification)
    if (message.data.isNotEmpty) {
      debugPrint('Processing data-only message: ${message.data}');

      // Store in Firestore if needed
      _storeNotificationInFirestore(message);
    }
  }

  // Configure background message handler
  void _configureBackgroundMessageHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Configure message opened app handler
  void _configureMessageOpenedAppHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      debugPrint('Message data: ${message.data}');

      // Handle the notification tap
      // For example, navigate to a specific screen based on the message data
      if (message.data.containsKey('type')) {
        final String type = message.data['type'];

        switch (type) {
          case 'community_notice':
            // Navigate to community notice details
            // Example: Navigator.pushNamed(context, '/community-notice', arguments: message.data['noticeId']);
            break;
          case 'chat':
            // Navigate to chat screen
            // Example: Navigator.pushNamed(context, '/chat', arguments: message.data['chatId']);
            break;
          case 'marketplace':
            // Navigate to marketplace item
            // Example: Navigator.pushNamed(context, '/marketplace-item', arguments: message.data['itemId']);
            break;
          default:
            // Default action
            break;
        }
      }
    });
  }

  // Store notification in Firestore
  Future<void> _storeNotificationInFirestore(RemoteMessage message) async {
    debugPrint('Storing notification in Firestore...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('Cannot store notification: User not logged in');
        return;
      }

      // Check if this notification already exists in Firestore
      // This prevents duplicate notifications when the server sends the same notification
      bool isDuplicate = false;

      // Check if the message contains a notificationId from the server
      if (message.data.containsKey('notificationId')) {
        final String notificationId = message.data['notificationId'];
        debugPrint('Message contains notificationId: $notificationId');

        // Check if a notification status already exists for this notification
        final existingStatus = await _firestore
            .collection('notification_status')
            .where('userId', isEqualTo: user.uid)
            .where('notificationId', isEqualTo: notificationId)
            .limit(1)
            .get();

        if (existingStatus.docs.isNotEmpty) {
          debugPrint('Notification already exists in Firestore, skipping creation');
          isDuplicate = true;
        }
      }

      // If not a duplicate, create the notification
      if (!isDuplicate) {
        // Determine if this is a community notification
        final bool isCommunityNotification = message.data.containsKey('communityId');
        final String? communityId = message.data['communityId'];

        // Create notification record in the appropriate collection
        DocumentReference notificationRef;

        if (isCommunityNotification && communityId != null) {
          // Check if the notification already exists in community_notifications
          if (message.data.containsKey('notificationId')) {
            final String notificationId = message.data['notificationId'];
            final existingDoc = await _firestore.collection('community_notifications').doc(notificationId).get();

            if (existingDoc.exists) {
              notificationRef = existingDoc.reference;
              debugPrint('Using existing community notification: ${notificationRef.id}');
            } else {
              // Create a new community notification
              notificationRef = await _firestore.collection('community_notifications').add({
                'title': message.notification?.title ?? message.data['title'],
                'body': message.notification?.body ?? message.data['body'],
                'type': message.data['type'] ?? 'communityNotices',
                'data': message.data,
                'communityId': communityId,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': message.data['authorId'] ?? 'system',
              });
              debugPrint('Created new community notification: ${notificationRef.id}');
            }
          } else {
            // Create a new community notification without an existing ID
            notificationRef = await _firestore.collection('community_notifications').add({
              'title': message.notification?.title ?? message.data['title'],
              'body': message.notification?.body ?? message.data['body'],
              'type': message.data['type'] ?? 'communityNotices',
              'data': message.data,
              'communityId': communityId,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': message.data['authorId'] ?? 'system',
            });
            debugPrint('Created new community notification: ${notificationRef.id}');
          }
        } else {
          // Create a user notification
          notificationRef = await _firestore.collection('user_notifications').add({
            'title': message.notification?.title ?? message.data['title'],
            'body': message.notification?.body ?? message.data['body'],
            'type': message.data['type'] ?? 'general',
            'data': message.data,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': 'system',
          });
          debugPrint('Created user notification: ${notificationRef.id}');
        }

        // Create a status record for this user
        await _firestore.collection('notification_status').add({
          'userId': user.uid,
          'notificationId': notificationRef.id,
          'communityId': isCommunityNotification ? communityId : null,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('Notification status created for user ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error storing notification in Firestore: $e');
    }
  }

  // Show a local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    debugPrint('Attempting to show local notification...');

    // Store the notification in Firestore
    await _storeNotificationInFirestore(message);

    // Skip local notification if plugins aren't available
    if (_localNotifications == null || _androidChannel == null) {
      debugPrint('Local notifications not available, skipping foreground notification');
      return;
    }

    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;

    // If `onMessage` is triggered with a notification, construct our own
    // local notification to show to users using the created channel.
    if (notification != null && android != null && !kIsWeb) {
      try {
        debugPrint('Showing local notification:');
        debugPrint('- Title: ${notification.title}');
        debugPrint('- Body: ${notification.body}');

        // For older versions of flutter_local_notifications, we use a different approach
        await _localNotifications!.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel!.id,
              _androidChannel!.name,
              channelDescription: _androidChannel!.description,
              icon: android.smallIcon ?? '@drawable/notification_icon',
              importance: Importance.high,
              priority: Priority.high,
              color: const Color(0xFF00C49A),
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );

        debugPrint('Local notification shown successfully');
      } catch (e) {
        debugPrint('ERROR showing local notification: $e');
      }
    }
  }

  // Get and save FCM token
  Future<void> _getAndSaveToken() async {
    try {
      debugPrint('Attempting to get FCM token...');

      // First check if we have permission
      try {
        final settings = await _messaging.getNotificationSettings();
        debugPrint('FCM Permission status: ${settings.authorizationStatus}');

        // If permission is not granted, request it
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('Permission not granted, requesting permission...');
          await _requestPermission();
        }
      } catch (settingsError) {
        debugPrint('Error getting notification settings: $settingsError');
        // Continue anyway, we'll try to get the token
      }

      // Try to get token directly
      try {
        debugPrint('Getting FCM token...');
        _token = await _messaging.getToken();
        debugPrint('FCM Token obtained: $_token');
      } catch (tokenError) {
        debugPrint('Error getting token: $tokenError');
        _token = null;
      }

      // Print token to make it easier to test
      if (_token != null) {
        debugPrint('==========================================');
        debugPrint('FCM TOKEN FOR TESTING: $_token');
        debugPrint('Copy this token to use in Firebase Console');
        debugPrint('==========================================');

        await _updateToken(_token!);
      } else {
        debugPrint('ERROR: FCM token is null!');
        debugPrint('This might be due to missing Firebase Messaging plugin registration');
        debugPrint('Check your Android/iOS configuration and rebuild the app');
      }
    } catch (e) {
      debugPrint('Error in _getAndSaveToken: $e');
      debugPrint(e.toString());
    }
  }

  // Get FCM token - public method to access the token
  Future<String?> getFcmToken() async {
    try {
      debugPrint('getFcmToken called');

      // If we already have a token, return it
      if (_token != null) {
        debugPrint('Returning existing token: $_token');
        return _token;
      }

      debugPrint('No existing token, attempting to get a new one...');

      // First check if we have permission
      try {
        final settings = await _messaging.getNotificationSettings();
        debugPrint('FCM Permission status: ${settings.authorizationStatus}');

        // If permission is not granted, request it
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('Permission not granted, requesting permission...');
          final newSettings = await _messaging.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
          debugPrint('New permission status: ${newSettings.authorizationStatus}');
        }
      } catch (settingsError) {
        debugPrint('Error getting notification settings: $settingsError');
        // Continue anyway, we'll try to get the token
      }

      // Get a new token
      try {
        debugPrint('Getting new FCM token...');
        _token = await _messaging.getToken();
        debugPrint('New token obtained: $_token');

        if (_token != null) {
          // Save the token
          await _updateToken(_token!);
          return _token;
        } else {
          debugPrint('WARNING: New token is null');
          return null;
        }
      } catch (tokenError) {
        debugPrint('Error getting new token: $tokenError');
        return 'Error: $tokenError';
      }
    } catch (e) {
      debugPrint('Error in getFcmToken: $e');
      return 'Error: $e';
    }
  }

  // Update token in Firestore with optimized handling for real-time notifications
  Future<void> _updateToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('Cannot update token: User not logged in');
      return;
    }

    try {
      debugPrint('Updating FCM token for user: ${user.uid} at ${DateTime.now().toIso8601String()}');
      debugPrint('Token to save: $token');

      // Use current timestamp instead of FieldValue.serverTimestamp() for array items
      final now = Timestamp.now();
      final tokenData = {
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'createdAt': now,
        'lastActive': now,
        'appVersion': '1.0.0', // Add app version for better tracking
        'deviceInfo': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        },
      };

      // Get existing tokens
      final userTokenDoc = await _firestore.collection('user_tokens').doc(user.uid).get();

      if (userTokenDoc.exists) {
        debugPrint('User token document exists, updating...');
        final data = userTokenDoc.data();

        // Check if tokens field exists and is a List
        final tokens = data?['tokens'] as List<dynamic>? ?? [];
        debugPrint('Current tokens count: ${tokens.length}');

        // Remove any expired or duplicate tokens (keep only the most recent 3)
        List<dynamic> updatedTokens = [...tokens];

        // Remove the current token if it exists (we'll add it back as the most recent)
        updatedTokens.removeWhere((t) => t['token'] == token);

        // Add the new token at the beginning (most recent)
        updatedTokens.insert(0, tokenData);

        // Keep only the 3 most recent tokens to avoid accumulating old tokens
        if (updatedTokens.length > 3) {
          updatedTokens = updatedTokens.sublist(0, 3);
        }

        // Update document with optimized settings
        debugPrint('Updating document with ${updatedTokens.length} tokens');
        await _firestore.collection('user_tokens').doc(user.uid).update({
          'tokens': updatedTokens,
          'lastActive': FieldValue.serverTimestamp(),
          'lastTokenUpdate': now,
          'deviceInfo': {
            'platform': Platform.operatingSystem,
            'version': Platform.operatingSystemVersion,
            'lastActive': now,
          },
        });

        debugPrint('FCM token updated in Firestore successfully');
      } else {
        debugPrint('User token document does not exist, creating new document');

        // Create new token document with optimized settings
        await _firestore.collection('user_tokens').doc(user.uid).set({
          'tokens': [tokenData],
          'notificationPreferences': {
            'communityNotices': true,
            'socialInteractions': true,
            'marketplace': true,
            'chat': true,
            'reports': true,
            'volunteer': true,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': now,
          'lastTokenUpdate': now,
          'deviceInfo': {
            'platform': Platform.operatingSystem,
            'version': Platform.operatingSystemVersion,
            'lastActive': now,
          },
        });

        debugPrint('New FCM token document created in Firestore');
      }

      // Verify token was saved by reading it back
      final verifyDoc = await _firestore.collection('user_tokens').doc(user.uid).get();
      if (verifyDoc.exists) {
        final data = verifyDoc.data();
        final tokens = data?['tokens'] as List<dynamic>? ?? [];
        bool tokenFound = false;

        for (final t in tokens) {
          if (t['token'] == token) {
            tokenFound = true;
            break;
          }
        }

        if (tokenFound) {
          debugPrint('Token verified in Firestore');
        } else {
          debugPrint('WARNING: Token not found in Firestore after update!');
        }
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      debugPrint(e.toString());

      // Fallback to simple update if the detailed update fails
      try {
        // Create a simple token object
        final simpleTokenData = {
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'createdAt': Timestamp.now(),
        };

        // Update with minimal data
        await _firestore.collection('user_tokens').doc(user.uid).update({
          'tokens': FieldValue.arrayUnion([simpleTokenData]),
          'lastActive': FieldValue.serverTimestamp(),
        });

        debugPrint('Token updated with fallback method');
      } catch (fallbackError) {
        debugPrint('Fallback token update also failed: $fallbackError');
      }
    }
  }

  // Get user notifications using the new structure
  Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // Get notification status records for this user
    return _firestore
        .collection('notification_status')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Get notification details by ID
  Future<Map<String, dynamic>?> getNotificationDetails(String notificationId, bool isCommunityNotification) async {
    try {
      final collection = isCommunityNotification ? 'community_notifications' : 'user_notifications';
      final doc = await _firestore.collection(collection).doc(notificationId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting notification details: $e');
      return null;
    }
  }

  // Test local notification
  Future<void> testLocalNotification() async {
    debugPrint('Testing local notification...');

    // First try to create a notification in Firestore using the new structure
    // This will at least show up in the app's notification list
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Create a single notification record
        final notificationRef = await _firestore.collection('user_notifications').add({
          'title': 'Test Notification',
          'body': 'This is a test notification from PULSE app',
          'type': 'test',
          'data': {'test': true},
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'system',
        });

        // Create a status record for this user
        await _firestore.collection('notification_status').add({
          'userId': user.uid,
          'notificationId': notificationRef.id,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint('Test notification created in Firestore using new structure');
      } else {
        debugPrint('Cannot create test notification in Firestore: User not logged in');
      }
    } catch (e) {
      debugPrint('ERROR creating test notification in Firestore: $e');
    }

    // Then try to show a local notification
    if (_localNotifications == null || _androidChannel == null) {
      debugPrint('Local notifications not available, cannot send test notification');
      throw Exception('Local notifications not available');
    }

    try {
      await _localNotifications!.show(
        0,
        'Test Notification',
        'This is a test notification from PULSE app',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel!.id,
            _androidChannel!.name,
            channelDescription: _androidChannel!.description,
            icon: '@drawable/notification_icon',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF00C49A),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test_notification',
      );

      debugPrint('Test notification sent successfully');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      throw Exception('Failed to send test notification: $e');
    }
  }

  // Mark notification as read and delete from notification_status to save storage
  // Returns the notification data before deleting so it can still be displayed
  Future<Map<String, dynamic>?> markNotificationAsRead(String statusId) async {
    try {
      // First get the notification status document to retrieve the notificationId and communityId
      final statusDoc = await _firestore.collection('notification_status').doc(statusId).get();

      if (!statusDoc.exists) {
        debugPrint('Notification status not found: $statusId');
        return null;
      }

      final statusData = statusDoc.data() as Map<String, dynamic>;
      final notificationId = statusData['notificationId'] as String?;
      final communityId = statusData['communityId'] as String?;

      if (notificationId == null) {
        debugPrint('Notification ID not found in status document');
        return null;
      }

      // Determine which collection to query based on whether it's a community notification
      final collection = communityId != null ? 'community_notifications' : 'user_notifications';

      // Get the actual notification document
      final notificationDoc = await _firestore.collection(collection).doc(notificationId).get();

      if (!notificationDoc.exists) {
        debugPrint('Notification document not found: $notificationId');
        return null;
      }

      // Get the notification data
      final notificationData = notificationDoc.data() as Map<String, dynamic>;

      // Create a combined data object with both status and notification data
      final combinedData = {
        ...notificationData,
        'statusId': statusId,
        'notificationId': notificationId,
        'read': true,
        'communityId': communityId,
      };

      // Delete the notification status document to save storage
      await _firestore.collection('notification_status').doc(statusId).delete();
      debugPrint('Notification status deleted to save storage: $statusId');

      return combinedData;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return null;
    }
  }

  // Mark all notifications as read for the current user and delete from notification_status
  // Returns a list of notification data that can still be displayed
  Future<List<Map<String, dynamic>>> markAllNotificationsAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get all unread notifications for this user
      final unreadNotifications = await _firestore
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isEmpty) {
        debugPrint('No unread notifications to mark as read');
        return [];
      }

      // Process each notification to get its data before deleting
      final List<Map<String, dynamic>> notificationDataList = [];
      final batch = _firestore.batch();

      for (final doc in unreadNotifications.docs) {
        try {
          final statusData = doc.data();
          final notificationId = statusData['notificationId'] as String?;
          final communityId = statusData['communityId'] as String?;

          if (notificationId != null) {
            // Determine which collection to query
            final collection = communityId != null ? 'community_notifications' : 'user_notifications';

            // Get the actual notification document
            final notificationDoc = await _firestore.collection(collection).doc(notificationId).get();

            if (notificationDoc.exists) {
              final notificationData = notificationDoc.data() as Map<String, dynamic>;

              // Create a combined data object
              final combinedData = {
                ...notificationData,
                'statusId': doc.id,
                'notificationId': notificationId,
                'read': true,
                'communityId': communityId,
              };

              notificationDataList.add(combinedData);
            }
          }

          // Mark for deletion
          batch.delete(doc.reference);
        } catch (e) {
          debugPrint('Error processing notification: $e');
        }
      }

      // Execute the batch delete
      await batch.commit();

      debugPrint('Marked and deleted ${unreadNotifications.docs.length} notifications');
      return notificationDataList;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return [];
    }
  }

  // Delete notification
  Future<void> deleteNotification(String statusId) async {
    try {
      // Only delete the status record, not the actual notification
      // This preserves the notification for other users
      await _firestore.collection('notification_status').doc(statusId).delete();

      debugPrint('Notification status deleted');
    } catch (e) {
      debugPrint('Error deleting notification status: $e');
    }
  }

  // Clean up old read notifications for the current user
  // This deletes only notifications that are older than the specified days
  // to save storage while keeping recent read notifications visible
  Future<void> cleanupReadNotifications({int olderThanDays = 30}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Calculate the cutoff date (notifications older than this will be deleted)
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Get all read notifications for this user that are older than the cutoff date
      final readNotifications = await _firestore
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: true)
          .get();

      // Filter locally to get only old notifications
      // (Firestore doesn't support multiple field filters without composite indexes)
      final oldNotifications = readNotifications.docs.where((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        return createdAt != null && createdAt.compareTo(cutoffTimestamp) < 0;
      }).toList();

      // Delete old read notifications
      if (oldNotifications.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in oldNotifications) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        debugPrint('Cleaned up ${oldNotifications.length} old read notifications from Firestore');
      } else {
        debugPrint('No old read notifications to clean up');
      }
    } catch (e) {
      debugPrint('Error cleaning up read notifications: $e');
    }
  }


  // Get notification preferences
  Future<Map<String, bool>> getNotificationPreferences() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'communityNotices': true,
        'socialInteractions': true,
        'marketplace': true,
        'chat': true,
        'reports': true,
        'volunteer': true,
      };
    }

    try {
      final userTokenDoc = await _firestore.collection('user_tokens').doc(user.uid).get();

      if (userTokenDoc.exists) {
        final data = userTokenDoc.data();
        final preferences = data?['notificationPreferences'] as Map<String, dynamic>? ?? {};

        return {
          'communityNotices': preferences['communityNotices'] ?? true,
          'socialInteractions': preferences['socialInteractions'] ?? true,
          'marketplace': preferences['marketplace'] ?? true,
          'chat': preferences['chat'] ?? true,
          'reports': preferences['reports'] ?? true,
          'volunteer': preferences['volunteer'] ?? true,
        };
      }
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
    }

    // Default preferences
    return {
      'communityNotices': true,
      'socialInteractions': true,
      'marketplace': true,
      'chat': true,
      'reports': true,
      'volunteer': true,
    };
  }

  // Update user notification preferences
  Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if document exists first
      final docSnapshot = await _firestore.collection('user_tokens').doc(user.uid).get();

      if (docSnapshot.exists) {
        // Update existing document
        await _firestore.collection('user_tokens').doc(user.uid).update({
          'notificationPreferences': preferences,
        });
      } else {
        // Create new document with preferences
        await _firestore.collection('user_tokens').doc(user.uid).set({
          'notificationPreferences': preferences,
          'tokens': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Notification preferences updated');
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  // Get unread notification count for the current user
  Future<int> getUnreadNotificationCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final unreadNotifications = await _firestore
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .count()
          .get();

      return unreadNotifications.count ?? 0;
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }

  // Get a stream of unread notification counts
  Stream<int> getUnreadNotificationCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    try {
      return _firestore
          .collection('notification_status')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      debugPrint('Error getting unread notification count stream: $e');
      return Stream.value(0);
    }
  }

  // Get community notifications stream
  Stream<QuerySnapshot> getCommunityNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      // Return an empty stream if no user is logged in
      return const Stream.empty();
    }

    // Get notifications for the current user
    return _firestore
        .collection('notification_status')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get community notifications for the user's community
  // This can be used to display notifications even after they're deleted from notification_status
  Future<List<Map<String, dynamic>>> getCommunityNotifications(String communityId, {int limit = 20}) async {
    try {
      debugPrint('Fetching community notifications for community: $communityId');

      // Get notifications for the community
      final snapshot = await _firestore
          .collection('community_notifications')
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No community notifications found');
        return [];
      }

      debugPrint('Found ${snapshot.docs.length} community notifications');

      // Convert to a list of maps
      final List<Map<String, dynamic>> notifications = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Create a complete notification object
        final notificationData = {
          ...data,
          'notificationId': doc.id,
          'statusId': doc.id, // Use the notification ID as the status ID for read notifications
          'read': true, // Assume read since we're fetching directly
          'source': 'community',
        };

        notifications.add(notificationData);
        debugPrint('Added notification: ${doc.id} - ${data['title']}');
      }

      return notifications;
    } catch (e) {
      debugPrint('Error getting community notifications: $e');
      return [];
    }
  }

  // Get user's community ID
  Future<String?> getUserCommunityId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['communityId'] as String?;
    } catch (e) {
      debugPrint('Error getting user community ID: $e');
      return null;
    }
  }
}
