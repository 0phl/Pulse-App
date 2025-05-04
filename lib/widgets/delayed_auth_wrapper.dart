import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../pages/login_page.dart';
import '../main.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/change_password_page.dart';
import '../models/admin_user.dart';
import '../pages/pending_verification_page.dart';
import '../pages/rejected_verification_page.dart';
import 'loading_screen.dart';
import '../services/user_session_service.dart';
import '../services/notification_service.dart';


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
    // Show loading screen for the specified delay
    Future.delayed(_loadingDelay, () {
      if (mounted) {
        _authenticate();
      }
    });
  }

  // Main authentication process
  Future<void> _authenticate() async {
    try {
      // Check for existing session
      await _getSessionWithTimeout();

      // Get current user
      final user = await _getCurrentUserWithTimeout();

      if (user == null) {
        // No user logged in, go to login page
        _navigateTo(const LoginPage());
        return;
      }

      // Check if user is admin
      final isAdmin = await _checkUserRoleWithTimeout();

      if (isAdmin) {
        // Get admin user data
        final adminUser = await _getAdminUserWithTimeout(user.uid);

        if (adminUser == null) {
          // Admin user data not found, go to login page
          _navigateTo(const LoginPage());
          return;
        }

        // Check if it's admin's first login
        if (adminUser.isFirstLogin) {
          // Redirect to change password page
          _navigateTo(const ChangePasswordPage());
        } else {
          // Redirect to admin dashboard
          _navigateTo(const AdminDashboardPage());
        }
      } else {
        // Regular user, check verification status
        final userDoc = await _getUserDocWithTimeout(user.uid);

        if (userDoc == null || !userDoc.exists) {
          // User document not found, go to login page
          _auth.signOut();
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
          _navigateTo(const MainScreen());
        } else {
          // Unknown verification status, go to login page
          _auth.signOut();
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
      // Initialize notification service if user is authenticated
      if (screen is! LoginPage) {
        _initializeNotificationService();
      }

      setState(() {
        _nextScreen = screen;
        _isAuthenticating = false;
      });
    }
  }

  // Initialize notification service
  Future<void> _initializeNotificationService() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      debugPrint('NotificationService initialized after authentication');
    } catch (e) {
      debugPrint('Error initializing NotificationService after authentication: $e');
    }
  }

  // Helper methods with timeout handling
  Future<bool> _getSessionWithTimeout() async {
    try {
      return await _sessionService.isLoggedIn()
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
      return await _adminService.isCurrentUserAdmin()
          .timeout(_timeoutDuration, onTimeout: () => false);
    } catch (e) {
      return false;
    }
  }

  Future<AdminUser?> _getAdminUserWithTimeout(String uid) async {
    try {
      return await _adminService.getAdminUser(uid).first
          .timeout(_timeoutDuration, onTimeout: () => null);
    } catch (e) {
      return null;
    }
  }

  Future<DocumentSnapshot?> _getUserDocWithTimeout(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get()
          .timeout(_timeoutDuration, onTimeout: () {
        throw TimeoutException('User document fetch timed out');
      });
    } catch (e) {
      return null;
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

    // Show the next screen after authentication
    return _nextScreen!;
  }
}
