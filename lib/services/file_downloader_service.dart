import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;


class FileDownloaderService {
  static final FileDownloaderService _instance = FileDownloaderService._internal();
  final Dio _dio = Dio();

  factory FileDownloaderService() {
    return _instance;
  }

  FileDownloaderService._internal();

  /// Downloads a file from the given URL and opens it
  /// Returns a Future<bool> indicating success or failure
  Future<bool> downloadAndOpenFile({
    required String url,
    required String fileName,
    required BuildContext context,
    Function(double)? onProgress,
  }) async {
    try {
      // Check and request storage permission
      if (!await _checkPermission()) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Storage permission is required to download files',
            isError: true,
          );
        }
        return false;
      }

      // Show downloading indicator
      if (context.mounted) {
        _showSnackBar(
          context,
          'Downloading $fileName...',
          duration: const Duration(seconds: 2),
        );
      }

      // Get the downloads directory
      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Could not access downloads directory',
            isError: true,
          );
        }
        return false;
      }

      // Create the file path
      final filePath = path.join(downloadsDir.path, fileName);
      final file = File(filePath);

      // Check if file already exists
      if (await file.exists()) {
        // If file exists, open it directly
        if (context.mounted) {
          _showSnackBar(
            context,
            'Opening $fileName...',
          );
          // Only proceed if context is still mounted
          return await _openFile(filePath, context);
        }
        return false;
      }

      // Download the file
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress?.call(progress);
          }
        },
        options: Options(
          headers: {
            HttpHeaders.acceptEncodingHeader: '*',
          },
        ),
      );

      // Show success message
      if (context.mounted) {
        _showSnackBar(
          context,
          'Download complete. Opening $fileName...',
        );

        // Open the file only if context is still mounted
        return await _openFile(filePath, context);
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Error: ${e.toString()}',
          isError: true,
        );
      }
      return false;
    }
  }

  /// Opens a file using the device's default app
  Future<bool> _openFile(String filePath, BuildContext context) async {
    try {
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Could not open file: ${result.message}',
            isError: true,
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Error opening file: $e',
          isError: true,
        );
      }
      return false;
    }
  }

  /// Checks and requests storage permission
  Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
      // Check Android version
      if (await _isAndroid11OrHigher()) {
        // For Android 11+, try both permissions
        // First try MANAGE_EXTERNAL_STORAGE
        final manageStatus = await Permission.manageExternalStorage.status;

        if (manageStatus.isDenied) {
          final result = await Permission.manageExternalStorage.request();
          if (result.isGranted) return true;

          // If MANAGE_EXTERNAL_STORAGE fails, try regular storage permission
          final storageStatus = await Permission.storage.status;
          if (storageStatus.isDenied) {
            final storageResult = await Permission.storage.request();
            return storageResult.isGranted;
          }
          return storageStatus.isGranted;
        }

        if (manageStatus.isGranted) return true;

        // If MANAGE_EXTERNAL_STORAGE is not granted, try regular storage
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isDenied) {
          final storageResult = await Permission.storage.request();
          return storageResult.isGranted;
        }
        return storageStatus.isGranted;
      } else {
        // For Android 10 and below, use storage permission
        final status = await Permission.storage.status;

        if (status.isDenied) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }

        return status.isGranted;
      }
    }

    // On iOS, we don't need explicit permission for downloads directory
    return true;
  }

  /// Helper method to check Android version
  Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      // Use a simpler approach based on Android release date
      // Android 11 was released in September 2020
      // This is a fallback approach since we're not using device_info_plus
      try {
        // Try to access a directory that requires MANAGE_EXTERNAL_STORAGE
        // This will fail on Android 11+ without the permission
        final testDir = Directory('/storage/emulated/0/Android/data');
        await testDir.exists();
        // If we get here, we're likely on Android 10 or below
        return false;
      } catch (e) {
        // If we get an exception, we're likely on Android 11+
        return true;
      }
    }
    return false;
  }

  /// Gets the downloads directory based on platform
  Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try multiple possible download paths for different Android versions
        final standardPath = Directory('/storage/emulated/0/Download');
        if (await standardPath.exists()) {
          return standardPath;
        }

        // Try alternative paths
        final altPath1 = Directory('/sdcard/Download');
        if (await altPath1.exists()) {
          return altPath1;
        }

        // For newer Android versions, try to use getExternalStorageDirectory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate up to find the Download directory
          final downloadDir = Directory('${externalDir.path.split('Android')[0]}Download');
          if (await downloadDir.exists()) {
            return downloadDir;
          }
        }

        // Last resort: use the app's documents directory
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        // On iOS, use the Documents directory
        return await getApplicationDocumentsDirectory();
      }
      return null;
    } catch (e) {
      // Fallback to temporary directory if we can't get the downloads directory
      return await getTemporaryDirectory();
    }
  }

  /// Shows a snackbar with the given message
  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration,
      ),
    );
  }
}


