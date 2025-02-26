import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_functions/cloud_functions.dart';

// Conditional import for web
import 'email_service_web.dart'
    if (dart.library.io) 'email_service_mobile.dart';

class EmailService {
  static const String _senderEmail = 'dgmt1511319@gmail.com';
  static const String _appPassword = 'zuri ueum uxco bqoy';
  static const String _emailJsPublicKey = 'LEGY3zCFy08HEgHUA';
  static const String _emailJsTemplateId = 'template_cjg4pne';
  static const String _emailJsServiceId = 'service_ztghbgm';

  final _smtpServer = gmail(_senderEmail, _appPassword);
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  late final EmailPlatform _emailPlatform;

  EmailService() {
    _emailPlatform = EmailPlatform(publicKey: _emailJsPublicKey);
  }

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
    await otpRef.set({'hash': hashedOTP, 'expiresAt': now, 'attempts': 0});
  }

  // Send email using SMTP
  Future<void> _sendEmail(Message message) async {
    try {
      print('Attempting to send email to: ${message.recipients.join(", ")}');
      final sendReport = await send(message, _smtpServer);
      print('Message sent: ' + sendReport.toString());
    } catch (e) {
      print('Error sending email: $e');
      throw Exception('Failed to send email: $e');
    }
  }

  // Send OTP email
  Future<void> sendOTP(String recipientEmail) async {
    final otp = _generateOTP();
    final hashedOTP = _generateHash(otp, recipientEmail);

    await _saveOTP(recipientEmail, hashedOTP);

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

    await _sendEmail(message);
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

  Future<void> sendAdminCredentials(
    String email,
    String fullName,
    String password,
    String communityName,
  ) async {
    print('EmailService: Preparing to send admin credentials');
    print('Sending to: $email');

    if (kIsWeb) {
      // Use EmailJS for web platform
      try {
        print('Using EmailJS for web platform');

        final templateParams = {
          'to_email': email,
          'to_name': fullName,
          'community_name': communityName,
          'password': password,
        };

        print('Sending email via EmailJS...');
        print('Service ID: $_emailJsServiceId');
        print('Template ID: $_emailJsTemplateId');

        await _emailPlatform.sendEmail(
          _emailJsServiceId,
          _emailJsTemplateId,
          templateParams,
        );

        print('EmailJS: Email sent successfully');
      } catch (e) {
        print('Error sending email via EmailJS: $e');
        throw Exception('Failed to send email via EmailJS: $e');
      }
    } else {
      // Use SMTP for non-web platforms
      try {
        final message = Message()
          ..from = Address(_senderEmail, 'PULSE App')
          ..recipients = [email]
          ..subject = 'Your Admin Account Credentials'
          ..html = '''
            <h2>Welcome to PULSE App Admin Panel</h2>
            <p>Dear $fullName,</p>
            <p>Your admin application for $communityName has been approved. Here are your login credentials:</p>
            <p><strong>Email:</strong> $email</p>
            <p><strong>Password:</strong> $password</p>
            <p>Please change your password after your first login.</p>
            <p>Best regards,<br>PULSE App Team</p>
          ''';

        await _sendEmail(message);
      } catch (e) {
        print('Error sending email via SMTP: $e');
        throw Exception('Failed to send email via SMTP: $e');
      }
    }
  }

  Future<void> sendRejectionNotification(String email, String reason) async {
    print('Sending rejection notification to: $email');

    final message = Message()
      ..from = Address(_senderEmail, 'PULSE App')
      ..recipients = [email]
      ..subject = 'Admin Application Status'
      ..html = '''
        <h2>Admin Application Update</h2>
        <p>We regret to inform you that your admin application has been rejected.</p>
        <p><strong>Reason:</strong> $reason</p>
        <p>If you believe this is a mistake or would like to submit additional information, please contact our support team.</p>
        <p>Best regards,<br>PULSE App Team</p>
      ''';

    await _sendEmail(message);
  }
}
