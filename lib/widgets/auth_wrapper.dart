import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_service.dart';
import '../pages/login_page.dart';
import '../main.dart';
import '../pages/admin/dashboard_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _adminService = AdminService();

  @override
  Widget build(BuildContext context) {
    // Only handle mobile auth routing
    if (kIsWeb) return Container();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // Check if user is admin
        return FutureBuilder<bool>(
          future: _checkUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (roleSnapshot.hasError) {
              return const LoginPage();
            }

            // Redirect to admin dashboard if admin, otherwise show regular user interface
            return roleSnapshot.data == true 
                ? const AdminDashboardPage() 
                : const MainScreen();
          },
        );
      },
    );
  }

  Future<bool> _checkUserRole() async {
    return await _adminService.isCurrentUserAdmin();
  }
}
