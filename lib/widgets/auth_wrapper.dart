import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/change_password_page.dart';
import '../models/admin_user.dart';
import '../pages/pending_verification_page.dart';
import '../pages/rejected_verification_page.dart';
import '../pages/deactivated_community_page.dart';
import '../services/user_session_service.dart';
import '../widgets/loading_screen.dart';
import '../pages/admin/deactivated_account_page.dart';
import '../main.dart'; // Import MainScreen from main.dart

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  static const Duration _timeoutDuration = Duration(seconds: 15);
  final _adminService = AdminService();
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _sessionService = UserSessionService();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return Container();

    return FutureBuilder<bool>(
      future: _getSessionWithTimeout(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(message: '');
        }

        // If we have a saved session but no current user, try to restore it
        if (sessionSnapshot.data == true && _auth.currentUser == null) {
          // We'll let the auth state stream handle this case
        }

        return FutureBuilder<User?>(
          future: _getCurrentUserWithTimeout(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen(message: '');
            }

            final user = snapshot.data;
            if (user == null) {
              print('AuthWrapper: No user logged in, returning to LoginPage');
              return const LoginPage();
            }

            print('AuthWrapper: User logged in: ${user.email}');

            return FutureBuilder<dynamic>(
              future: _checkUserRoleWithTimeout(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  print('AuthWrapper: Checking user role...');
                  return const LoadingScreen(message: '');
                }

                if (roleSnapshot.hasError) {
                  print(
                      'AuthWrapper: Error checking role: ${roleSnapshot.error}');
                  return const LoginPage();
                }

                if (roleSnapshot.data is AdminAuthResult) {
                  final adminResult = roleSnapshot.data as AdminAuthResult;
                  if (adminResult.status == AdminAuthStatus.deactivated) {
                    print(
                        'AuthWrapper: Account is deactivated with reason: ${adminResult.deactivationReason}');
                    return DeactivatedAccountPage(
                      reason: adminResult.deactivationReason,
                    );
                  }
                }

                if (roleSnapshot.data == true) {
                  return FutureBuilder<AdminUser?>(
                    future: _getAdminUserWithTimeout(_auth.currentUser!.uid),
                    builder: (context, adminSnapshot) {
                      if (adminSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        print('AuthWrapper: Loading admin user data...');
                        return const LoadingScreen(message: '');
                      }

                      if (adminSnapshot.hasError) {
                        print(
                            'AuthWrapper: Error loading admin data: ${adminSnapshot.error}');
                        return const LoginPage();
                      }

                      final adminUser = adminSnapshot.data;
                      if (adminUser == null) {
                        print('AuthWrapper: Admin user data is null');
                        return const LoginPage();
                      }

                      print('AuthWrapper: Admin User: ${adminUser.toMap()}');
                      print(
                          'AuthWrapper: Is first login? ${adminUser.isFirstLogin}');

                      // Redirect to change password page if it's first login
                      if (adminUser.isFirstLogin) {
                        print('AuthWrapper: Redirecting to ChangePasswordPage');
                        return const ChangePasswordPage();
                      } else {
                        print('AuthWrapper: Redirecting to AdminDashboardPage');
                        return const AdminDashboardPage();
                      }
                    },
                  );
                }

                // For regular users, check verification status with timeout
                return FutureBuilder<DocumentSnapshot?>(
                  future: _getUserDocWithTimeout(user.uid),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingScreen(message: '');
                    }

                    if (userSnapshot.hasError ||
                        !userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      print(
                          'AuthWrapper: Error fetching user data: ${userSnapshot.error}');
                      // Sign out if we can't verify the user status
                      try {
                        debugPrint('AuthWrapper: Signing out user with AuthService');
                        _authService.signOut();
                      } catch (e) {
                        debugPrint('AuthWrapper: Error signing out: $e');
                      }
                      return const LoginPage();
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final verificationStatus =
                        userData['verificationStatus'] as String?;

                    print(
                        'AuthWrapper: User verification status: $verificationStatus');

                    if (verificationStatus == 'pending') {
                      print(
                          'AuthWrapper: User account is pending verification');
                      return PendingVerificationPage(
                        registrationId:
                            userData['registrationId'] as String? ?? '',
                      );
                    } else if (verificationStatus == 'rejected') {
                      print('AuthWrapper: User account has been rejected');
                      // Import the rejected verification page at the top of the file
                      return RejectedVerificationPage(
                        registrationId:
                            userData['registrationId'] as String? ?? '',
                        rejectionReason: userData['rejectionReason'] as String?,
                      );
                    } else if (verificationStatus == 'verified') {
                      print(
                          'AuthWrapper: User is verified, checking community status');

                      return FutureBuilder<CommunityDeactivationStatus>(
                        future: _checkCommunityStatusWithTimeout(),
                        builder: (context, communitySnapshot) {
                          if (communitySnapshot.connectionState == ConnectionState.waiting) {
                            return const LoadingScreen(message: '');
                          }

                          // If community is deactivated, show deactivated community page
                          if (communitySnapshot.data?.isDeactivated == true) {
                            print('AuthWrapper: Community is deactivated');
                            return const DeactivatedCommunityPage();
                          }

                          // Community is active, show regular user interface
                          print('AuthWrapper: Community is active, showing regular UI');
                          return const MainScreen();
                        },
                      );
                    } else {
                      print(
                          'AuthWrapper: Unknown verification status: $verificationStatus');
                      // Sign out if verification status is unknown
                      try {
                        debugPrint('AuthWrapper: Signing out user with AuthService');
                        _authService.signOut();
                      } catch (e) {
                        debugPrint('AuthWrapper: Error signing out: $e');
                      }
                      return const LoginPage();
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper methods with timeout handling
  Future<bool> _getSessionWithTimeout() async {
    try {
      return await _sessionService.isLoggedIn().timeout(_timeoutDuration,
          onTimeout: () {
        print('Session check timed out');
        return false;
      });
    } catch (e) {
      print('Error checking session: $e');
      return false;
    }
  }

  Future<User?> _getCurrentUserWithTimeout() async {
    try {
      return await Future.delayed(const Duration(milliseconds: 500), () {
        return _auth.currentUser;
      }).timeout(_timeoutDuration, onTimeout: () {
        print('Auth state check timed out');
        return null;
      });
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<dynamic> _checkUserRoleWithTimeout() async {
    try {
      final adminResult = await _adminService
          .checkAdminStatus()
          .timeout(_timeoutDuration, onTimeout: () {
        print('User role check timed out');
        return AdminAuthResult(status: AdminAuthStatus.notAdmin);
      });

      // If the account is deactivated, return the result so we can show the deactivated page
      if (adminResult.status == AdminAuthStatus.deactivated) {
        return adminResult;
      }

      // Otherwise return a simple boolean for backward compatibility
      return adminResult.status == AdminAuthStatus.authenticated;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  Future<AdminUser?> _getAdminUserWithTimeout(String uid) async {
    try {
      // Convert stream to future with timeout
      return await _adminService
          .getAdminUser(uid)
          .first
          .timeout(_timeoutDuration, onTimeout: () {
        print('Admin user fetch timed out');
        return null;
      });
    } catch (e) {
      print('Error getting admin user: $e');
      return null;
    }
  }

  Future<DocumentSnapshot?> _getUserDocWithTimeout(String uid) async {
    try {
      // We need to handle the timeout differently since DocumentSnapshot can't be null
      final result = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_timeoutDuration, onTimeout: () {
        print('User document fetch timed out');
        throw TimeoutException('User document fetch timed out');
      });
      return result;
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  Future<CommunityDeactivationStatus> _checkCommunityStatusWithTimeout() async {
    try {
      return await _userService
          .checkCommunityStatus()
          .timeout(_timeoutDuration, onTimeout: () {
        print('Community status check timed out');
        // On timeout, assume community is active to prevent false positives
        return CommunityDeactivationStatus.active();
      });
    } catch (e) {
      print('Error checking community status: $e');
      // On error, assume community is active to prevent false positives
      return CommunityDeactivationStatus.active();
    }
  }
}
