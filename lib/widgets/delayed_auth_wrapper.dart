import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../pages/login_page.dart';
import '../main.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/change_password_page.dart';
import '../models/admin_user.dart';
import '../pages/pending_verification_page.dart';
import '../pages/rejected_verification_page.dart';
import '../pages/deactivated_community_page.dart';
import 'loading_screen.dart';
import '../services/user_session_service.dart';
import '../services/notification_service.dart';
import '../services/user_activity_service.dart';

class DelayedAuthWrapper extends StatefulWidget {
  const DelayedAuthWrapper({super.key});

  @override
  State<DelayedAuthWrapper> createState() => _DelayedAuthWrapperState();
}

class _DelayedAuthWrapperState extends State<DelayedAuthWrapper> {
  // Constants
  static const Duration _timeoutDuration = Duration(seconds: 15);
  static const Duration _loadingDelay = Duration(seconds: 3);

  // Services
  final _sessionService = UserSessionService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _adminService = AdminService();
  final _userService = UserService();
  final _authService = AuthService();
  final _activityService = UserActivityService();

  // State variables
  bool _isAuthenticating = true;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    // Start authentication process after a delay
    _startAuthenticationProcess();
  }

  // Start the authentication process after the loading delay
  void _startAuthenticationProcess() {
    Future.delayed(_loadingDelay, () {
      if (mounted) {
        _authenticate();
      }
    });
  }

  // Main authentication process
  Future<void> _authenticate() async {
    try {
      await _getSessionWithTimeout();

      final user = await _getCurrentUserWithTimeout();

      if (user == null) {
        // No user logged in, go to login page
        _navigateTo(const LoginPage());
        return;
      }

      final isAdmin = await _checkUserRoleWithTimeout();

      if (isAdmin) {
        final adminUser = await _getAdminUserWithTimeout(user.uid);

        if (adminUser == null) {
          // Admin user data not found, go to login page
          _navigateTo(const LoginPage());
          return;
        }

        if (adminUser.isFirstLogin) {
          // Redirect to change password page
          _navigateTo(const ChangePasswordPage());
        } else {
          // Redirect to admin dashboard
          // Track admin activity
          await _activityService.onAppResumed();
          _navigateTo(const AdminDashboardPage());
        }
      } else {
        // Regular user, check verification status
        final userDoc = await _getUserDocWithTimeout(user.uid);

        if (userDoc == null || !userDoc.exists) {
          // User document not found, go to login page
          try {
            debugPrint('DelayedAuthWrapper: Signing out user with AuthService');
            await _authService.signOut();
            debugPrint('DelayedAuthWrapper: Logout completed successfully');
          } catch (e) {
            debugPrint('DelayedAuthWrapper: Error signing out: $e');
          }
          _navigateTo(const LoginPage());
          return;
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final verificationStatus = userData['verificationStatus'] as String?;

        // Navigate based on verification status
        if (verificationStatus == 'pending') {
          _navigateTo(PendingVerificationPage(
            registrationId: userData['registrationId'] as String? ?? '',
          ));
        } else if (verificationStatus == 'rejected') {
          _navigateTo(RejectedVerificationPage(
            registrationId: userData['registrationId'] as String? ?? '',
            rejectionReason: userData['rejectionReason'] as String?,
          ));
        } else if (verificationStatus == 'verified') {
          final communityStatus = await _checkCommunityStatusWithTimeout();
          if (communityStatus.isDeactivated) {
            // Community is deactivated, show deactivated community page
            _navigateTo(const DeactivatedCommunityPage());
          } else {
            // Community is active, show regular user interface
            // Track that user opened the app
            await _activityService.onAppResumed();
            _navigateTo(const MainScreen());
          }
        } else {
          // Unknown verification status, go to login page
          try {
            debugPrint('DelayedAuthWrapper: Signing out user with AuthService');
            await _authService.signOut();
            debugPrint('DelayedAuthWrapper: Logout completed successfully');
          } catch (e) {
            debugPrint('DelayedAuthWrapper: Error signing out: $e');
          }
          _navigateTo(const LoginPage());
        }
      }
    } catch (e) {
      // Error during authentication, go to login page
      _navigateTo(const LoginPage());
    }
  }

  // Helper method to navigate to a screen
  void _navigateTo(Widget screen) {
    if (mounted) {
      if (screen is! LoginPage) {
        _initializeNotificationService();
      }

      setState(() {
        _nextScreen = screen;
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _initializeNotificationService() async {
    // Wait for the auth state to confirm a user is logged in
    await _auth.authStateChanges().firstWhere((user) => user != null);

    // Double-check currentUser after waiting for the stream
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint(
          'Error: User became null unexpectedly after authStateChanges.');
      return; // Don't proceed if user is somehow null again
    }

    debugPrint(
        'User confirmed by authStateChanges: ${currentUser.uid}. Initializing NotificationService...');

    try {
      final notificationService = NotificationService();

      // First initialize the notification service
      await notificationService.initialize();
      debugPrint('NotificationService initialized after authentication');

      // Then explicitly reset the token to ensure it's properly saved
      await notificationService.resetTokenAfterLogin();
      debugPrint(
          'FCM token explicitly reset after authentication in DelayedAuthWrapper');
    } catch (e) {
      debugPrint(
          'Error initializing NotificationService after authentication: $e');
    }
  }

  // Helper methods with timeout handling
  Future<bool> _getSessionWithTimeout() async {
    try {
      return await _sessionService
          .isLoggedIn()
          .timeout(_timeoutDuration, onTimeout: () => false);
    } catch (e) {
      return false;
    }
  }

  Future<User?> _getCurrentUserWithTimeout() async {
    try {
      return await Future.delayed(const Duration(milliseconds: 500), () {
        return _auth.currentUser;
      }).timeout(_timeoutDuration, onTimeout: () => null);
    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkUserRoleWithTimeout() async {
    try {
      return await _adminService
          .isCurrentUserAdmin()
          .timeout(_timeoutDuration, onTimeout: () => false);
    } catch (e) {
      return false;
    }
  }

  Future<AdminUser?> _getAdminUserWithTimeout(String uid) async {
    try {
      return await _adminService
          .getAdminUser(uid)
          .first
          .timeout(_timeoutDuration, onTimeout: () => null);
    } catch (e) {
      return null;
    }
  }

  Future<DocumentSnapshot?> _getUserDocWithTimeout(String uid) async {
    try {
      return await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_timeoutDuration, onTimeout: () {
        throw TimeoutException('User document fetch timed out');
      });
    } catch (e) {
      return null;
    }
  }

  Future<CommunityDeactivationStatus> _checkCommunityStatusWithTimeout() async {
    try {
      return await _userService.checkCommunityStatus().timeout(_timeoutDuration,
          onTimeout: () {
        // On timeout, assume community is active to prevent false positives
        return CommunityDeactivationStatus.active();
      });
    } catch (e) {
      // On error, assume community is active to prevent false positives
      return CommunityDeactivationStatus.active();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show the loading screen until authentication is complete
    if (_isAuthenticating || _nextScreen == null) {
      return const LoadingScreen(
        message: '', // Empty message for a cleaner look
      );
    }

    return _nextScreen!;
  }
}
