import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _lastUpdateTime;
  Timer? _periodicTimer;
  static const Duration _updateInterval =
      Duration(minutes: 5); // Update every 5 minutes max
  static const Duration _periodicInterval =
      Duration(minutes: 10); // Check every 10 minutes

  bool _isInitialized = false;

  /// Updates the user's lastActive timestamp in Firestore
  /// Only updates if more than 5 minutes have passed since last update to avoid too many writes
  Future<void> updateUserActivity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();

      // Rate limiting: only update if enough time has passed
      if (_lastUpdateTime != null &&
          now.difference(_lastUpdateTime!) < _updateInterval) {
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });

      _lastUpdateTime = now;
      debugPrint('Updated user activity for ${user.uid}');
    } catch (e) {
      // Silently fail - this shouldn't break the app
      debugPrint('Error updating user activity: $e');
    }
  }

  /// Force update user activity (ignores rate limiting)
  Future<void> forceUpdateUserActivity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });

      _lastUpdateTime = DateTime.now();
      debugPrint('Force updated user activity for ${user.uid}');
    } catch (e) {
      debugPrint('Error force updating user activity: $e');
    }
  }

  /// Initialize comprehensive activity tracking
  void initialize() {
    if (_isInitialized) return;

    debugPrint(
        'UserActivityService: Initializing comprehensive activity tracking');

    // Set up app lifecycle listener
    _setupAppLifecycleListener();

    // Start periodic activity updates
    _startPeriodicUpdates();

    _isInitialized = true;
  }

  /// Set up app lifecycle listener
  void _setupAppLifecycleListener() {
    SystemChannels.lifecycle.setMessageHandler((message) async {
      debugPrint('UserActivityService: App lifecycle changed to $message');

      switch (message) {
        case 'AppLifecycleState.resumed':
          // User returned to app
          await onAppResumed();
          break;
        case 'AppLifecycleState.paused':
          // User left app
          await onAppPaused();
          break;
        case 'AppLifecycleState.inactive':
          // App became inactive
          break;
        case 'AppLifecycleState.detached':
          // App is detached
          await onAppDetached();
          break;
      }
      return null;
    });
  }

  /// Start periodic activity updates while app is active
  void _startPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicInterval, (timer) {
      updateUserActivity();
    });
  }

  /// Stop periodic updates
  void _stopPeriodicUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Called when app is resumed (user returned to app)
  Future<void> onAppResumed() async {
    debugPrint('UserActivityService: App resumed - updating user activity');
    await forceUpdateUserActivity();
    _startPeriodicUpdates(); // Resume periodic updates
  }

  /// Called when app is paused (user left app)
  Future<void> onAppPaused() async {
    debugPrint('UserActivityService: App paused - final activity update');
    await forceUpdateUserActivity();
    _stopPeriodicUpdates(); // Stop periodic updates to save battery
  }

  /// Called when app is detached
  Future<void> onAppDetached() async {
    await onAppPaused(); // Same as paused
  }

  /// Call this when user logs in
  Future<void> onUserLogin() async {
    debugPrint(
        'UserActivityService: User logged in - initializing activity tracking');
    await forceUpdateUserActivity();
    initialize(); // Initialize tracking after login
  }

  /// Call this when user logs out
  Future<void> onUserLogout() async {
    debugPrint(
        'UserActivityService: User logged out - cleaning up activity tracking');
    _lastUpdateTime = null;
    _stopPeriodicUpdates();
    _isInitialized = false;
  }

  /// Initialize activity tracking for a new user
  Future<void> initializeUserActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
      debugPrint('Initialized user activity for $userId');
    } catch (e) {
      debugPrint('Error initializing user activity: $e');
    }
  }

  /// Track specific user actions
  Future<void> trackUserAction(String action) async {
    debugPrint('UserActivityService: User performed action: $action');
    await updateUserActivity();
  }

  /// Track navigation between pages
  Future<void> trackPageNavigation(String pageName) async {
    debugPrint('UserActivityService: User navigated to: $pageName');
    await updateUserActivity();
  }

  /// Clean up resources
  void dispose() {
    _stopPeriodicUpdates();
    _isInitialized = false;
  }
}
