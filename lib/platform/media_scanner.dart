import 'package:flutter/services.dart';

/// A class to handle platform-specific media scanning functionality
class MediaScanner {
  static const MethodChannel _channel = MethodChannel('com.pulse.app/media_scanner');

  /// Scans a file to make it visible in the gallery immediately
  static Future<bool> scanFile(String filePath) async {
    try {
      final result = await _channel.invokeMethod('scanFile', {'path': filePath});
      return result == true;
    } catch (e) {
      print('MediaScanner: Error scanning file: $e');
      return false;
    }
  }
}
