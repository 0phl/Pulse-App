@JS()
library email_service_web;

import 'dart:convert';
import 'dart:js_util';
import 'package:js/js.dart';
import 'dart:html';

@JS()
@anonymous
class EmailJSParams {
  external factory EmailJSParams({
    String to_email,
    String to_name,
    String community_name,
    String password,
  });
}

@JS('emailjs')
external dynamic get emailjs;

@JS('emailjs.init')
external void initEmailJs(String publicKey);

@JS('emailjs.send')
external dynamic sendEmailJS(
    String serviceId, String templateId, EmailJSParams params);

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

      // Create EmailJS parameters using the proper JS interop
      final emailParams = EmailJSParams(
        to_email: params['to_email'] as String,
        to_name: params['to_name'] as String,
        community_name: params['community_name'] as String,
        password: params['password'] as String,
      );

      print('Sending with EmailJS parameters...');

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
