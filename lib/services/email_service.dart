import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

class EmailService {
  static const String _senderEmail = 'dgmt1511319@gmail.com';
  static const String _appPassword = 'zuri ueum uxco bqoy';

  final _smtpServer = gmail(_senderEmail, _appPassword);
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Generate a secure random OTP
  String _generateOTP() {
    final random = Random.secure();
    final otp = List.generate(6, (_) => random.nextInt(10)).join();
    return otp;
  }

  // Generate hash for OTP verification
  String _generateHash(String otp, String email) {
    final bytes = utf8.encode(otp + email);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Save OTP data to Firebase
  Future<void> _saveOTP(String email, String hashedOTP) async {
    final otpRef = _database.child('otps').child(email.replaceAll('.', '_'));
    final now = DateTime.now().millisecondsSinceEpoch;
    await otpRef.set({
      'hash': hashedOTP,
      'expiresAt': now,
      'attempts': 0
    });
  }

  // Send OTP email
  Future<void> sendOTP(String recipientEmail) async {
    final otp = _generateOTP();
    final hashedOTP = _generateHash(otp, recipientEmail);

    // Save OTP data to Firebase
    await _saveOTP(recipientEmail, hashedOTP);

    // Create the email message
    final message = Message()
      ..from = Address(_senderEmail, 'PULSE App')
      ..recipients = [recipientEmail]
      ..subject = 'Your OTP Verification Code'
      ..html = '''
        <h2>Email Verification</h2>
        <p>Your OTP verification code is:</p>
        <h1 style="font-size: 32px; letter-spacing: 5px; color: #4CAF50;">$otp</h1>
        <p>This code will expire in 3 minutes.</p>
        <p>If you did not request this code, please ignore this email.</p>
      ''';

    try {
      await send(message, _smtpServer);
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    final otpRef = _database.child('otps').child(email.replaceAll('.', '_'));
    final snapshot = await otpRef.get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final expiresAt = data['expiresAt'] as int;
    final attempts = data['attempts'] as int;
    final storedHash = data['hash'] as String;

    // Check if OTP is expired (3 minutes)
    if (DateTime.now().millisecondsSinceEpoch > expiresAt + (3 * 60 * 1000)) {
      await otpRef.remove();
      return false;
    }

    // Check if too many attempts
    if (attempts >= 3) {
      await otpRef.remove();
      return false;
    }

    // Increment attempts
    await otpRef.update({'attempts': attempts + 1});

    // Verify OTP
    final inputHash = _generateHash(otp, email);
    if (inputHash == storedHash) {
      await otpRef.remove(); // Clean up after successful verification
      return true;
    }

    return false;
  }
}
