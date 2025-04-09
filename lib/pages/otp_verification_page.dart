import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../models/registration_data.dart';
import '../services/email_service.dart';
import '../services/auth_service.dart';
import '../main.dart';

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

          String normalizeString(String input) {
            // Convert to uppercase first since barangay names from LocationService are uppercase
            var normalized = input.toUpperCase();

            // Remove 'BARANGAY' prefix
            normalized = normalized.replaceAll(RegExp(r'BARANGAY\s+'), '');

            // Convert Roman numerals to numbers
            normalized = normalized
              .replaceAll('III', '3')
              .replaceAll('II', '2');

            // Remove all spaces
            normalized = normalized.replaceAll(RegExp(r'\s+'), '');

            return normalized;
          }

      // Get all communities to check
      final communitiesRef = FirebaseDatabase.instance.ref().child('communities');
      final allCommunitiesSnapshot = await communitiesRef.get();

      String? communityId;
      if (allCommunitiesSnapshot.exists) {
        final allCommunities = allCommunitiesSnapshot.value as Map<dynamic, dynamic>;

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

      // Now register with the correct communityId
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
      );

      if (mounted && userCredential != null) {
        // Clear navigation stack and go to main screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
        _otpController.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
      ),
      body: SingleChildScrollView(
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
      ),
    );
  }
}
