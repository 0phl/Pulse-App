import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';

class DeactivatedAccountPage extends StatefulWidget {
  final String? reason;

  const DeactivatedAccountPage({
    super.key,
    this.reason,
  });

  @override
  State<DeactivatedAccountPage> createState() => _DeactivatedAccountPageState();
}

class _DeactivatedAccountPageState extends State<DeactivatedAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<Map<String, dynamic>> _adminData;
  final String _superAdminEmail = 'pulseappsupport@gmail.com';

  @override
  void initState() {
    super.initState();
    _adminData = _loadAdminData();
  }

  // Load additional admin data
  Future<Map<String, dynamic>> _loadAdminData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'deactivationReason': widget.reason ??
              'Your account has been deactivated by the super admin.',
          'adminName': 'Admin',
          'email': '',
          'deactivatedAt': DateTime.now(),
        };
      }

      final userData = await _firestore.collection('users').doc(user.uid).get();

      if (!userData.exists) {
        return {
          'deactivationReason': widget.reason ??
              'Your account has been deactivated by the super admin.',
          'adminName': user.displayName ?? 'Admin',
          'email': user.email ?? '',
          'deactivatedAt': DateTime.now(),
        };
      }

      final data = userData.data()!;
      return {
        'deactivationReason': data['deactivationReason'] ??
            widget.reason ??
            'Your account has been deactivated by the super admin.',
        'adminName': data['fullName'] ?? user.displayName ?? 'Admin',
        'email': data['email'] ?? user.email ?? '',
        'deactivatedAt': data['deactivatedAt'] is Timestamp
            ? (data['deactivatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      };
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      return {
        'deactivationReason': widget.reason ??
            'Your account has been deactivated by the super admin.',
        'adminName': 'Admin',
        'email': '',
        'deactivatedAt': DateTime.now(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _adminData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C49A),
                    ),
                  );
                }

                final adminData = snapshot.data ??
                    {
                      'deactivationReason':
                          'Your account has been deactivated by the super admin.',
                      'adminName': 'Admin',
                      'email': '',
                      'deactivatedAt': DateTime.now(),
                    };

                return Column(
                  children: [
                    // Header with lock icon and title
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.only(
                          top: 40, bottom: 24, left: 20, right: 20),
                      child: Column(
                        children: [
                          // Lock icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              size: 40,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Account Deactivated',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF4444),
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Main content area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Admin profile section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[100],
                                    child: Text(
                                      adminData['adminName']
                                              .toString()
                                              .isNotEmpty
                                          ? adminData['adminName'][0]
                                              .toUpperCase()
                                          : 'N',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          adminData['adminName'] ?? 'Admin',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (adminData['email'] != null &&
                                            adminData['email']
                                                .toString()
                                                .isNotEmpty)
                                          Text(
                                            adminData['email'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Deactivation message
                            Text(
                              'Your account access has been revoked by the Super Admin.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Reason card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reason for Deactivation:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    adminData['deactivationReason'],
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Date of deactivation
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Deactivated on: ${_formatDate(adminData['deactivatedAt'])}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // What should I do section
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF059669),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'What should I do?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Please contact the Super Admin to discuss the reactivation of your account. You may need to provide additional information or resolve the issues mentioned in the deactivation reason.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF065F46),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.email_outlined,
                                        size: 16,
                                        color: Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Contact: $_superAdminEmail',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sign out button at bottom
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').add_jm().format(date);
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
