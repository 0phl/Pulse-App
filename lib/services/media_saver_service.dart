import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import '../platform/media_scanner.dart';

/// A service for saving media (images and videos) to the device gallery
/// and handling the necessary permissions.
class MediaSaverService {
  // Singleton pattern
  static final MediaSaverService _instance = MediaSaverService._internal();
  factory MediaSaverService() => _instance;
  MediaSaverService._internal();

  /// Saves an image to the gallery.
  ///
  /// [filePath] is the path to the image file.
  /// [context] is used to show snackbar messages.
  /// [album] is an optional album name to save the image to.
  Future<bool> saveImageToGallery({
    required String filePath,
    required BuildContext context,
    String? album,
  }) async {
    try {
      // Check and request permissions
      if (!await _checkPermission(context)) {
        return false;
      }

      // Show saving indicator
      if (context.mounted) {
        _showSnackBar(
          context,
          'Saving image to gallery...',
          duration: const Duration(seconds: 1),
        );
      }

      // Create a new file with current timestamp to ensure it appears as the newest file
      final newFilePath = await _createFileWithCurrentTimestamp(filePath);

      // Save the image
      if (album != null) {
        await Gal.putImage(newFilePath, album: album);
      } else {
        await Gal.putImage(newFilePath);
      }

      // Show success message
      if (context.mounted) {
        _showSnackBar(
          context,
          'Image saved to gallery successfully!',
        );
        return true;
      }
      return false;
    } on GalException catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Error: ${e.type.message}',
          isError: true,
        );
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

  /// Saves a video to the gallery.
  ///
  /// [filePath] is the path to the video file.
  /// [context] is used to show snackbar messages.
  /// [album] is an optional album name to save the video to.
  Future<bool> saveVideoToGallery({
    required String filePath,
    required BuildContext context,
    String? album,
  }) async {
    try {
      // Check and request permissions
      if (!await _checkPermission(context)) {
        debugPrint('MediaSaverService: Permission denied for saving video');
        return false;
      }

      // Show saving indicator
      if (context.mounted) {
        _showSnackBar(
          context,
          'Saving video to gallery...',
          duration: const Duration(seconds: 2),
        );
      }

      // Verify the file exists and is readable
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('MediaSaverService: Video file does not exist: $filePath');
        if (context.mounted) {
          _showSnackBar(
            context,
            'Error: Video file not found',
            isError: true,
          );
        }
        return false;
      }

      // Log file size and path for debugging
      final fileSize = await file.length();
      debugPrint('MediaSaverService: Video file size: ${fileSize ~/ 1024} KB');
      debugPrint('MediaSaverService: Original file path: $filePath');

      // Create a new file with current timestamp to ensure it appears as the newest file
      final newFilePath = await _createFileWithCurrentTimestamp(filePath);
      debugPrint('MediaSaverService: New file path: $newFilePath');

      // Verify the new file exists
      final newFile = File(newFilePath);
      if (!await newFile.exists()) {
        debugPrint('MediaSaverService: New video file was not created properly');
        if (context.mounted) {
          _showSnackBar(
            context,
            'Error: Failed to process video file',
            isError: true,
          );
        }
        return false;
      }

      // Try alternative approach if on Android 10+ (API 29+)
      if (Platform.isAndroid) {
        try {
          // First try with Gal package
          if (album != null) {
            debugPrint('MediaSaverService: Saving video to album: $album');
            await Gal.putVideo(newFilePath, album: album);
          } else {
            debugPrint('MediaSaverService: Saving video without album');
            await Gal.putVideo(newFilePath);
          }
        } catch (galError) {
          debugPrint('MediaSaverService: Gal error: $galError, trying fallback method');

          // Fallback: Try using MediaStore API directly for Android 10+
          if (await _isAndroid10OrHigher()) {
            debugPrint('MediaSaverService: Using MediaStore fallback for Android 10+');
            final result = await _saveVideoUsingMediaStore(newFilePath, album);
            if (!result) {
              throw Exception('Failed to save video using MediaStore API');
            }
          } else {
            // Re-throw if not Android 10+ as we don't have a fallback
            rethrow;
          }
        }
      } else {
        // Non-Android platforms
        if (album != null) {
          await Gal.putVideo(newFilePath, album: album);
        } else {
          await Gal.putVideo(newFilePath);
        }
      }

      // Show success message
      if (context.mounted) {
        _showSnackBar(
          context,
          'Video saved to gallery successfully!',
        );
        return true;
      }
      return false;
    } on GalException catch (e) {
      debugPrint('MediaSaverService: GalException: ${e.type.message}');
      if (context.mounted) {
        _showSnackBar(
          context,
          'Error: ${e.type.message}',
          isError: true,
        );
      }
      return false;
    } catch (e) {
      debugPrint('MediaSaverService: Exception: ${e.toString()}');
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

  /// Helper method to check if device is running Android 10 or higher
  Future<bool> _isAndroid10OrHigher() async {
    if (Platform.isAndroid) {
      return await Permission.storage.status.isGranted ||
          await Permission.storage.status.isDenied ||
          await Permission.storage.status.isPermanentlyDenied;
    }
    return false;
  }

  /// Fallback method to save video using MediaStore API for Android 10+
  Future<bool> _saveVideoUsingMediaStore(String filePath, String? album) async {
    try {
      // This is a simplified implementation - in a real app, you would use
      // platform channels to access MediaStore API directly
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final fileName = path.basename(filePath);

      // Get the app's external storage directory
      final appDir = await getExternalStorageDirectory();
      if (appDir == null) return false;

      // Create album directory if needed
      final albumDir = album != null
          ? Directory('${appDir.path}/DCIM/$album')
          : Directory('${appDir.path}/DCIM');

      if (!await albumDir.exists()) {
        await albumDir.create(recursive: true);
      }

      // Save the file to the album directory
      final savedFile = File('${albumDir.path}/$fileName');
      await savedFile.writeAsBytes(bytes);

      // Notify media scanner to index the new file
      await _scanFile(savedFile.path);
      debugPrint('MediaSaverService: Video saved to ${savedFile.path}');

      return true;
    } catch (e) {
      debugPrint('MediaSaverService: Error in _saveVideoUsingMediaStore: $e');
      return false;
    }
  }

  /// Scans a file to make it visible in the gallery immediately
  Future<void> _scanFile(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // Use our platform-specific implementation to scan the file
        debugPrint('MediaSaverService: Scanning file: $filePath');
        final result = await MediaScanner.scanFile(filePath);
        debugPrint('MediaSaverService: Scan result: $result');
      }
    } catch (e) {
      debugPrint('MediaSaverService: Error scanning file: $e');
    }
  }

  /// Saves a document (PDF, DOC, etc.) to the device's Downloads directory.
  ///
  /// [filePath] is the path to the document file.
  /// [context] is used to show snackbar messages.
  /// [album] is an optional folder name within Downloads to save the document to.
  Future<bool> saveDocumentToDownloads({
    required String filePath,
    required BuildContext context,
    String? album,
  }) async {
    try {
      // Check and request permissions
      if (!await _checkPermission(context)) {
        return false;
      }

      // Show saving indicator
      if (context.mounted) {
        _showSnackBar(
          context,
          'Saving document...',
          duration: const Duration(seconds: 2),
        );
      }

      // Get the file extension
      final extension = path.extension(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'PULSE_$timestamp$extension';

      // Get the downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Try to get the Downloads directory on Android
        try {
          // Try standard Download directory first
          final standardPath = Directory('/storage/emulated/0/Download');
          if (await standardPath.exists()) {
            downloadsDir = standardPath;
          } else {
            // Try alternative paths
            final altPath = Directory('/sdcard/Download');
            if (await altPath.exists()) {
              downloadsDir = altPath;
            } else {
              // Last resort: use the app's documents directory
              downloadsDir = await getApplicationDocumentsDirectory();
            }
          }
        } catch (e) {
          // Fallback to app's documents directory
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        // On iOS/macOS, use the Documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows) {
        // On Windows, use the Downloads directory
        final appDocDir = await getApplicationDocumentsDirectory();
        final parentDir = Directory(path.dirname(appDocDir.path));
        downloadsDir = Directory('${parentDir.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      } else {
        // Fallback for other platforms
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      // Create album directory if specified
      if (album != null && album.isNotEmpty) {
        final albumDir = Directory('${downloadsDir.path}/$album');
        if (!await albumDir.exists()) {
          await albumDir.create(recursive: true);
        }
        downloadsDir = albumDir;
      }

      // Create the destination file path
      final destinationPath = '${downloadsDir.path}/$newFileName';

      // Copy the file to the destination
      final sourceFile = File(filePath);
      await sourceFile.copy(destinationPath);

      // Show success message
      if (context.mounted) {
        _showSnackBar(
          context,
          'Document saved to Downloads successfully!',
        );
        return true;
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

  /// Checks and requests storage permission
  Future<bool> _checkPermission(BuildContext context) async {
    // First check if we already have access using Gal's built-in method
    final hasAccess = await Gal.hasAccess();
    if (hasAccess) return true;

    // If not, request access using Gal's method first
    final requestResult = await Gal.requestAccess();
    if (requestResult) return true;

    // If Gal's method fails, try using permission_handler as a fallback
    if (Platform.isAndroid) {
      // For Android, check if we're on Android 11+ (API 30+)
      if (await _isAndroid11OrHigher()) {
        // For Android 11+, we need to request storage permissions differently
        final storageStatus = await Permission.photos.status;
        if (storageStatus.isDenied) {
          final result = await Permission.photos.request();
          if (result.isGranted) return true;
        } else if (storageStatus.isGranted) {
          return true;
        }
      } else {
        // For Android 10 and below, use storage permission
        final status = await Permission.storage.status;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          if (result.isGranted) return true;
        } else if (status.isGranted) {
          return true;
        }
      }
    } else if (Platform.isIOS) {
      // For iOS, request photos permission
      final status = await Permission.photos.status;
      if (status.isDenied) {
        final result = await Permission.photos.request();
        if (result.isGranted) return true;
      } else if (status.isGranted) {
        return true;
      }
    }

    // If we get here, permission was denied
    if (context.mounted) {
      _showSnackBar(
        context,
        'Storage permission is required to save media to gallery',
        isError: true,
      );
    }
    return false;
  }

  /// Helper method to check if device is running Android 11 or higher
  Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      return await Permission.photos.status.isGranted ||
          await Permission.photos.status.isDenied ||
          await Permission.photos.status.isPermanentlyDenied;
    }
    return false;
  }

  /// Creates a new file with the current timestamp in the filename and metadata
  /// to ensure it appears as the newest file in the gallery
  Future<String> _createFileWithCurrentTimestamp(String originalFilePath) async {
    try {
      // Get the original file extension
      final extension = path.extension(originalFilePath).toLowerCase();
      final originalFile = File(originalFilePath);

      // Create a new filename with current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'PULSE_$timestamp$extension';

      // Get temporary directory for the new file
      final tempDir = await getTemporaryDirectory();
      final newFilePath = path.join(tempDir.path, newFileName);

      debugPrint('MediaSaverService: Creating new file with timestamp: $newFilePath');

      // For images, we'll decode and re-encode to reset metadata
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(extension)) {
        try {
          // Read the original file as bytes
          final bytes = await originalFile.readAsBytes();

          // Decode the image
          final image = img.decodeImage(bytes);

          if (image != null) {
            // Encode the image (this creates a new image with current timestamp)
            Uint8List? encodedImage;

            if (extension == '.jpg' || extension == '.jpeg') {
              encodedImage = img.encodeJpg(image, quality: 90);
            } else if (extension == '.png') {
              encodedImage = img.encodePng(image);
            } else if (extension == '.gif') {
              encodedImage = img.encodeGif(image);
            } else {
              encodedImage = img.encodePng(image); // Default to PNG for other formats
            }

            // Write the new image to file
            await File(newFilePath).writeAsBytes(encodedImage);
            debugPrint('MediaSaverService: Image processed and saved to $newFilePath');
            return newFilePath;
          }
        } catch (imageError) {
          // If image processing fails, fall back to simple copy
          debugPrint('MediaSaverService: Error processing image: $imageError, falling back to copy');
        }
      } else if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension)) {
        // For video files, use a more reliable copy method
        debugPrint('MediaSaverService: Processing video file');
        try {
          // Read the original file as bytes and write to new file
          final bytes = await originalFile.readAsBytes();
          await File(newFilePath).writeAsBytes(bytes);

          // Scan the file to make it visible in the gallery
          await _scanFile(newFilePath);

          debugPrint('MediaSaverService: Video processed and saved to $newFilePath');
          return newFilePath;
        } catch (videoError) {
          debugPrint('MediaSaverService: Error processing video: $videoError, falling back to copy');
        }
      }

      // For other file types or if processing failed, just copy the file
      debugPrint('MediaSaverService: Copying file directly');
      await originalFile.copy(newFilePath);

      // Try to update the file's last modified time to ensure it appears as newest
      try {
        final newFile = File(newFilePath);
        await newFile.setLastModified(DateTime.now());

        // For videos, scan the file to make it visible in the gallery
        if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension)) {
          await _scanFile(newFilePath);
        }
      } catch (timeError) {
        debugPrint('MediaSaverService: Error updating file timestamp: $timeError');
      }

      return newFilePath;
    } catch (e) {
      // If there's an error, return the original file path
      debugPrint('MediaSaverService: Error creating file with timestamp: $e');
      return originalFilePath;
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
        backgroundColor: isError ? Colors.red : null,
        duration: duration,
      ),
    );
  }
}
