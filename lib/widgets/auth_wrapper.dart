import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../pages/login_page.dart';
import '../main.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/change_password_page.dart';
import '../models/admin_user.dart';
import '../pages/pending_verification_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _adminService = AdminService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return Container();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) {
          print('AuthWrapper: No user logged in, returning to LoginPage');
          return const LoginPage();
        }

        print('AuthWrapper: User logged in: ${user.email}');

        // Check if user is admin
        return FutureBuilder<bool>(
          future: _checkUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              print('AuthWrapper: Checking user role...');
              return const Center(child: CircularProgressIndicator());
            }

            if (roleSnapshot.hasError) {
              print('AuthWrapper: Error checking role: ${roleSnapshot.error}');
              return const LoginPage();
            }

            print('AuthWrapper: Is admin? ${roleSnapshot.data}');

            if (roleSnapshot.data == true) {
              // Check if it's admin's first login
              return StreamBuilder<AdminUser?>(
                stream: _adminService.getAdminUser(_auth.currentUser!.uid),
                builder: (context, adminSnapshot) {
                  if (adminSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    print('AuthWrapper: Loading admin user data...');
                    return const Center(child: CircularProgressIndicator());
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

            // For regular users, check verification status
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(user.uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError ||
                    !userSnapshot.hasData ||
                    !userSnapshot.data!.exists) {
                  print(
                      'AuthWrapper: Error fetching user data: ${userSnapshot.error}');
                  // Sign out if we can't verify the user status
                  _auth.signOut();
                  return const LoginPage();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final verificationStatus =
                    userData['verificationStatus'] as String?;

                print(
                    'AuthWrapper: User verification status: $verificationStatus');

                // If user account is pending verification, show pending screen
                if (verificationStatus == 'pending') {
                  print('AuthWrapper: User account is pending verification');
                  return PendingVerificationPage(
                    registrationId: userData['registrationId'] as String? ?? '',
                  );
                }

                print('AuthWrapper: User is verified, showing regular UI');
                // User is verified, show regular user interface
                return const MainScreen();
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _checkUserRole() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();
    print('_checkUserRole: isAdmin = $isAdmin');
    return isAdmin;
  }
}
