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
  static const String _emailJsApprovalTemplateId = 'template_cjg4pne';
  static const String _emailJsRejectionTemplateId = 'template_8z8syof';
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
      print('Message sent: $sendReport');
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
      ..from = const Address(_senderEmail, 'PULSE App')
      ..recipients = [recipientEmail]
      ..subject = 'Your OTP Verification Code'
      ..html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verification - PULSE App</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #F5F5F5;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff;">
                    <!-- Header -->
                    <tr>
                        <td style="background-color: #00C49A; padding: 30px 20px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 500;">Email Verification</h1>
                        </td>
                    </tr>

                    <!-- Content -->
                    <tr>
                        <td style="padding: 30px;">
                            <div style="text-align: center; margin-bottom: 30px;">
                                <h2 style="color: #00C49A; margin-bottom: 15px;">Verify Your Email Address</h2>
                                <p style="margin: 0; color: #666666; font-size: 16px;">Please use the verification code below to complete your registration:</p>
                            </div>

                            <!-- OTP Code Box -->
                            <div style="background-color: #E0F7F3; border: 2px solid #00C49A; border-radius: 8px; padding: 25px; margin: 20px 0; text-align: center;">
                                <h3 style="color: #00C49A; letter-spacing: 5px; font-size: 32px; margin: 0; font-family: monospace;">$otp</h3>
                            </div>

                            <!-- Timer Notice -->
                            <div style="background-color: #FFF4E5; border-left: 4px solid #FF9800; padding: 20px; margin: 20px 0;">
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td width="24" style="vertical-align: top; padding-right: 10px;">⏳</td>
                                        <td>
                                            <p style="margin: 0; color: #E65100; font-weight: 500;">This code will expire in 3 minutes</p>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <!-- Security Notice -->
                            <div style="background-color: #F8F9FA; border: 1px solid #E9ECEF; padding: 20px; margin: 20px 0;">
                                <p style="margin: 0; color: #666666; font-size: 14px;">
                                    If you did not request this verification code, please ignore this email. Your account security is important to us.
                                </p>
                            </div>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #E0F7F3; padding: 20px; text-align: center;">
                            <p style="margin: 0 0 10px 0; color: #666666;">Best regards,<br>PULSE App Team</p>
                            <small style="color: #666666;">This is an automated message, please do not reply directly to this email.</small>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
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

    if (DateTime.now().millisecondsSinceEpoch > expiresAt + (3 * 60 * 1000)) {
      await otpRef.remove();
      return false;
    }

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
        print('Template ID: $_emailJsApprovalTemplateId');

        await _emailPlatform.sendEmail(
          _emailJsServiceId,
          _emailJsApprovalTemplateId,
          templateParams,
        );

        print('EmailJS: Email sent successfully');
      } catch (e) {
        print('Error sending email via EmailJS: $e');
        throw Exception('Failed to send email via EmailJS: $e');
      }
    } else {
      try {
        final message = Message()
          ..from = const Address(_senderEmail, 'PULSE App')
          ..recipients = [email]
          ..subject = 'Your Admin Account Credentials'
          ..html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #F5F5F5;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff;">
                    <tr>
                        <td style="background-color: #00C49A; padding: 30px 20px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 500;">Welcome to PULSE App</h1>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px;">
                            <div style="text-align: center; margin-bottom: 30px;">
                                <h2 style="color: #00C49A; margin-bottom: 15px;">Congratulations, $fullName!</h2>
                                <p style="margin: 0;">Your admin application for <strong>$communityName</strong> has been approved.</p>
                            </div>

                            <div style="background-color: #E0F7F3; border-left: 4px solid #00C49A; padding: 20px; margin: 20px 0;">
                                <h3 style="color: #00C49A; margin-top: 0;">Your Admin Credentials</h3>
                                <p style="margin: 10px 0;"><strong>Email:</strong> $email</p>
                                <p style="margin: 10px 0;"><strong>Password:</strong> $password</p>
                            </div>

                            <div style="background-color: #FFF4E5; border-left: 4px solid #FF9800; padding: 20px; margin: 20px 0;">
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td width="24" style="vertical-align: top; padding-right: 10px;">⚠️</td>
                                        <td>
                                            <h4 style="color: #E65100; margin: 0 0 10px 0;">Important Security Notice</h4>
                                            <p style="color: #795548; margin: 0;">For your security, please change your password immediately after your first login. This helps ensure the safety of your admin account.</p>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #007F6D, #00C49A); margin: 25px 0;">
                                <tr>
                                    <td style="padding: 25px; text-align: center;">
                                        <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                            <tr>
                                                <td style="text-align: center; padding-bottom: 15px;">
                                                    <span style="font-size: 20px;">📱</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <h3 style="margin: 0 0 15px 0; color: #FFFFFF; font-size: 18px; font-weight: 600;">
                                                        Getting Started
                                                    </h3>
                                                    <p style="margin: 0; color: #FFFFFF; font-size: 16px; line-height: 1.6;">
                                                        Use these credentials to access your admin account through the PULSE mobile app
                                                    </p>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            <div style="background-color: #E0F7F3; padding: 20px; margin: 20px 0;">
                                <h4 style="color: #00C49A; margin-top: 0;">Your Admin Capabilities:</h4>
                                <ul style="margin: 0; padding-left: 20px;">
                                    <li style="margin: 8px 0;">Manage your community settings</li>
                                    <li style="margin: 8px 0;">Monitor community activities</li>
                                    <li style="margin: 8px 0;">Handle user reports and moderation</li>
                                    <li style="margin: 8px 0;">Access analytics and insights</li>
                                </ul>
                            </div>

                            <p style="margin: 20px 0;">If you need any assistance or have questions, don't hesitate to contact our support team.</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="background-color: #E0F7F3; padding: 20px; text-align: center;">
                            <p style="margin: 0 0 10px 0;">Best regards,<br>PULSE App Team</p>
                            <small style="color: #666666;">This is an automated message, please do not reply directly to this email.</small>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
          ''';

        await _sendEmail(message);
      } catch (e) {
        print('Error sending email via SMTP: $e');
        throw Exception('Failed to send email via SMTP: $e');
      }
    }
  }

  Future<void> sendRejectionNotification(String email, String reason) async {
    print('EmailService: Preparing to send rejection notification');
    print('Sending to: $email');

    if (kIsWeb) {
      try {
        print('Using EmailJS for web platform');
        print('Email: $email');
        print('Reason: $reason');

        if (email.isEmpty) {
          throw Exception('Email address cannot be empty');
        }
        if (reason.isEmpty) {
          throw Exception('Rejection reason cannot be empty');
        }

        final templateParams = {
          'to_email': email,
          'rejection_reason': reason,
        };

        print('Template parameters:');
        print(templateParams);
        print('Sending rejection email via EmailJS...');
        print('Service ID: $_emailJsServiceId');
        print('Template ID: $_emailJsRejectionTemplateId');

        await _emailPlatform.sendEmail(
          _emailJsServiceId,
          _emailJsRejectionTemplateId,
          templateParams,
        );

        print('EmailJS: Rejection email sent successfully');
      } catch (e) {
        print('Error sending rejection email via EmailJS: $e');
        throw Exception('Failed to send rejection email via EmailJS: $e');
      }
    } else {
      try {
        print('Sending rejection notification via SMTP');
        final message = Message()
          ..from = const Address(_senderEmail, 'PULSE App')
          ..recipients = [email]
          ..subject = 'Application Status Update'
          ..html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #F5F5F5;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff;">
                    <tr>
                        <td style="background-color: #FF6B6B; padding: 30px 20px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 500;">Application Status Update</h1>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px;">
                            <div style="margin-bottom: 25px;">
                                <p style="margin: 0; color: #333333; font-size: 16px;">Dear $email,</p>
                            </div>

                            <div style="margin-bottom: 25px;">
                                <p style="margin: 0; color: #333333; line-height: 1.6;">
                                    We have carefully reviewed your admin application for the PULSE App community management position. After thorough consideration, we regret to inform you that we are unable to move forward with your application at this time.
                                </p>
                            </div>

                            <div style="margin: 25px 0; padding: 20px; background: #FFF5F5; border-left: 4px solid #FF6B6B;">
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td width="24" style="vertical-align: top; padding-right: 10px;">❗</td>
                                        <td>
                                            <h4 style="margin: 0 0 10px 0; color: #DC3545; font-size: 16px;">Reason for Decision</h4>
                                            <p style="margin: 0; color: #666666; line-height: 1.6;">$reason</p>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <div style="margin: 25px 0; padding: 20px; background-color: #F8F9FA; border: 1px solid #E9ECEF;">
                                <h4 style="margin: 0 0 10px 0; color: #00C49A;">Need Assistance?</h4>
                                <p style="margin: 0; color: #666666; line-height: 1.6;">
                                    If you believe this decision was made in error or would like to submit additional information, please contact our support team. We're here to help address any questions or concerns you may have.
                                </p>
                            </div>

                            <div style="margin: 25px 0;">
                                <p style="margin: 0; color: #333333; line-height: 1.6;">
                                    We sincerely appreciate your interest in being part of the PULSE App community and the time you invested in your application. We encourage you to apply again in the future if you feel you have addressed the concerns mentioned above.
                                </p>
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 20px; text-align: center; background-color: #F8F9FA;">
                            <p style="margin: 0 0 10px 0; color: #666666;">
                                Best regards,<br>
                                <strong style="color: #00C49A;">PULSE App Team</strong>
                            </p>
                            <small style="color: #999999;">This is an automated message, please do not reply directly to this email.</small>
                        </td>
                    </tr>
                    <tr>
                        <td style="height: 4px; background: linear-gradient(to right, #FF6B6B, #FF8787);"></td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
          ''';

        await _sendEmail(message);
        print('SMTP: Rejection email sent successfully');
      } catch (e) {
        print('Error sending rejection email via SMTP: $e');
        throw Exception('Failed to send rejection email via SMTP: $e');
      }
    }
  }
}
