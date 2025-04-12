import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/registration_data.dart';
import '../services/email_service.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/login_page.dart';

class OTPVerificationPage extends StatefulWidget {
  final RegistrationData registrationData;

  const OTPVerificationPage({
    Key? key,
    required this.registrationData,
  }) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final EmailService _emailService = EmailService();
  final AuthService _authService = AuthService();
  Timer? _timer;
  int _timeLeft = 180; // 3 minutes in seconds
  bool _isLoading = false;
  bool _canResend = false;
  bool _emailVerified = false; // Track if email is verified

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendOTP(); // Send OTP when page loads
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 180;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _sendOTP() async {
    try {
      await _emailService.sendOTP(widget.registrationData.email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeLeft() {
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await _emailService.verifyOTP(
        widget.registrationData.email,
        otp,
      );

      if (!isValid) {
        throw Exception('Invalid OTP code');
      }

      // Email is now verified, update state
      setState(() {
        _emailVerified = true;
        _isLoading = false;
      });

      // Get all communities to check
      final communitiesRef =
          FirebaseDatabase.instance.ref().child('communities');
      final allCommunitiesSnapshot = await communitiesRef.get();

      String? communityId;
      if (allCommunitiesSnapshot.exists) {
        final allCommunities =
            allCommunitiesSnapshot.value as Map<dynamic, dynamic>;

        // Get barangay code from registration data
        final barangayCode = widget.registrationData.location['barangayCode'];

        // Manually check each community since we can't query by locationStatusId without an index
        for (var entry in allCommunities.entries) {
          final community = entry.value as Map<dynamic, dynamic>;

          // Check if this community matches our barangay code and is active
          if (community['barangayCode'] == barangayCode &&
              community['status'] == 'active' &&
              community['adminId'] != null) {
            // Found an active community for this barangay
            communityId = entry.key;
            break;
          }
        }
      }

      if (communityId == null) {
        throw 'Community not found. Please ensure your barangay has an active community.';
      }

      // Now register with the correct communityId, but don't navigate away - we'll show the pending screen
      final userCredential = await _authService.registerWithEmailAndPassword(
        email: widget.registrationData.email,
        password: widget.registrationData.password,
        fullName: widget.registrationData.fullName,
        username: widget.registrationData.username,
        mobile: widget.registrationData.mobile,
        birthDate: widget.registrationData.birthDate,
        address: widget.registrationData.address,
        location: widget.registrationData.location,
        communityId: communityId,
        registrationId: widget.registrationData.registrationId,
        verificationStatus: 'pending',
      );

      // The user account is created but we remain on this page to show the QR code
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
        _otpController.clear();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Widget to show pending status with QR code
  Widget _buildPendingStatusScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Color(0xFF00C49A),
          ),
          const SizedBox(height: 24),
          Text(
            'Email Verified Successfully!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00C49A),
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
            padding: const EdgeInsets.all(12),
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
                  data: widget.registrationData.registrationId,
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
                  widget.registrationData.registrationId,
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
                _buildStep(4, 'Wait for the admin to verify your information'),
                _buildStep(5, 'Once approved, you can fully access the app'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Sign out and navigate to login page instead of main screen
              // This will let AuthWrapper handle the verification status check
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue to Login',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A),
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

  // Widget to show OTP verification UI
  Widget _buildOTPVerificationScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          Text(
            'Enter Verification Code',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'We\'ve sent a verification code to:',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.registrationData.email,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              enabled: !_isLoading,
              autoFocus: true,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 50,
                fieldWidth: 40,
                activeFillColor: Colors.white,
                activeColor: Theme.of(context).primaryColor,
                selectedColor: Theme.of(context).primaryColor,
                inactiveColor: Colors.grey,
              ),
              onCompleted: _verifyOTP,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: 24),
          if (!_canResend) ...[
            Text(
              'Code expires in: ${_formatTimeLeft()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_canResend)
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _sendOTP();
                      _startTimer();
                    },
              child: const Text('Resend Code'),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_emailVerified ? 'Account Verification' : 'Verify Your Email'),
      ),
      body: _emailVerified
          ? _buildPendingStatusScreen()
          : _buildOTPVerificationScreen(),
    );
  }
}
