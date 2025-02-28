@JS()
library email_service_web;

import 'dart:convert';
import 'dart:js_util';
import 'package:js/js.dart';
import 'dart:html';

@JS()
@anonymous
class EmailJSApprovalParams {
  external factory EmailJSApprovalParams({
    String to_email,
    String to_name,
    String community_name,
    String password,
  });
}

@JS()
@anonymous
class EmailJSRejectionParams {
  external factory EmailJSRejectionParams({
    String to_email,
    String rejection_reason,
  });
}

@JS('emailjs')
external dynamic get emailjs;

@JS('emailjs.init')
external void initEmailJs(String publicKey);

@JS('emailjs.send')
external dynamic sendEmailJS(
    String serviceId, String templateId, dynamic params);

class EmailPlatform {
  static bool _initialized = false;
  final String publicKey;

  EmailPlatform({required this.publicKey}) {
    if (!_initialized) {
      try {
        print('Initializing EmailJS...');
        initEmailJs(publicKey);
        _initialized = true;
        print('EmailJS initialized successfully');
      } catch (e) {
        print('Error initializing EmailJS: $e');
        throw Exception('Failed to initialize EmailJS: $e');
      }
    }
  }

  Future<void> sendEmail(
      String serviceId, String templateId, Map<String, dynamic> params) async {
    try {
      print('Starting email send process...');
      print('Service ID: $serviceId');
      print('Template ID: $templateId');
      print('Parameters: ${jsonEncode(params)}');

      // Validate required parameters
      if (!params.containsKey('to_email') || params['to_email'] == null || params['to_email'].toString().isEmpty) {
        throw Exception('to_email is required');
      }

      // Create EmailJS parameters based on template type
      dynamic emailParams;
      if (templateId == 'template_cjg4pne') {  // Approval template
        // Validate approval-specific parameters
        if (!params.containsKey('to_name') || params['to_name'] == null) {
          throw Exception('to_name is required for approval template');
        }
        if (!params.containsKey('community_name') || params['community_name'] == null) {
          throw Exception('community_name is required for approval template');
        }
        if (!params.containsKey('password') || params['password'] == null) {
          throw Exception('password is required for approval template');
        }

        emailParams = EmailJSApprovalParams(
          to_email: params['to_email'] as String,
          to_name: params['to_name'] as String,
          community_name: params['community_name'] as String,
          password: params['password'] as String,
        );
        print('Created approval parameters for: ${params['to_email']}');
      } else if (templateId == 'template_8z8syof') {  // Rejection template
        // Validate rejection-specific parameters
        if (!params.containsKey('rejection_reason') || params['rejection_reason'] == null) {
          throw Exception('rejection_reason is required for rejection template');
        }

        emailParams = EmailJSRejectionParams(
          to_email: params['to_email'] as String,
          rejection_reason: params['rejection_reason'] as String,
        );
        print('Created rejection parameters for: ${params['to_email']}');
      } else {
        throw Exception('Unknown template ID: $templateId');
      }

      print('Sending with EmailJS parameters for template: $templateId');
      print('Final parameters being sent:');
      print(emailParams);

      try {
        // Send email using EmailJS
        final result = await promiseToFuture(
            sendEmailJS(serviceId, templateId, emailParams));

        print('Raw EmailJS Response: $result');
        final response = dartify(result);
        print('Parsed EmailJS Response: $response');

        print('Email sent successfully via EmailJS');
      } catch (jsError) {
        print('JavaScript Error: $jsError');
        throw Exception('EmailJS send failed: $jsError');
      }
    } catch (e, stackTrace) {
      print('Detailed EmailJS error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to send email via EmailJS: $e');
    }
  }
}
