import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';

class PendingVerificationPage extends StatelessWidget {
  final String registrationId;

  const PendingVerificationPage({
    super.key,
    required this.registrationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Verification"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = AuthService();
              try {
                debugPrint('PendingVerificationPage: Starting logout process with AuthService');
                await authService.signOut();
                debugPrint('PendingVerificationPage: Logout completed successfully');
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              } catch (e) {
                debugPrint('PendingVerificationPage: Error during logout: $e');
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pending_outlined,
              size: 80,
              color: Color(0xFF00C49A),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Pending',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C49A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your account is pending verification. Please visit your barangay office to complete the in-person verification process.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Show this QR code to the barangay admin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: registrationId,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Registration ID:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    registrationId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Next Steps:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                      1, 'Visit your barangay office during working hours'),
                  _buildStep(2, 'Present this QR code to the barangay admin'),
                  _buildStep(3, 'Bring a valid ID for identity verification'),
                  _buildStep(
                      4, 'Wait for the admin to verify your information'),
                  _buildStep(5, 'Once approved, you can fully access the app'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final authService = AuthService();
                try {
                  debugPrint('PendingVerificationPage: Starting logout process with AuthService');
                  await authService.signOut();
                  debugPrint('PendingVerificationPage: Logout completed successfully');
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                } catch (e) {
                  debugPrint('PendingVerificationPage: Error during logout: $e');
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build steps
  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF00C49A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
