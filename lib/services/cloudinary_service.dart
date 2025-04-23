import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;

  late final CloudinaryPublic adminCloudinary;
  late final CloudinaryPublic marketCloudinary;
  late final CloudinaryPublic noticeCloudinary;
  late final CloudinaryPublic reportCloudinary;
  late final CloudinaryPublic profileCloudinary;

  CloudinaryService._internal() {
    adminCloudinary = CloudinaryPublic('dy1jizr52', 'Admin_docs', cache: false);
    marketCloudinary =
        CloudinaryPublic('dy1jizr52', 'market_images', cache: false);
    noticeCloudinary =
        CloudinaryPublic('dy1jizr52', 'community_notices', cache: false);
    reportCloudinary =
        CloudinaryPublic('dy1jizr52', 'community_reports', cache: false);
    profileCloudinary =
        CloudinaryPublic('dy1jizr52', 'profile_images', cache: false);
  }

  Future<String> uploadMarketImage(File file) async {
    try {
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'market',
      );

      CloudinaryResponse response =
          await marketCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload market image: $e');
    }
  }

  Future<String> uploadNoticeImage(File file) async {
    try {
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'notices',
      );

      CloudinaryResponse response =
          await noticeCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload notice image: $e');
    }
  }

  Future<List<String>> uploadNoticeImages(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      String url = await uploadNoticeImage(file);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadNoticeVideo(File file) async {
    try {
      // Get file info
      final String fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      // Check if file is a supported video format
      final List<String> supportedFormats = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'];
      if (!supportedFormats.contains(fileExtension)) {
        throw Exception('Unsupported video format: $fileExtension. Supported formats are: ${supportedFormats.join(', ')}');
      }

      // Check file size
      final int fileSizeInBytes = await file.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // Compress video if it's larger than 5MB
      File videoFile = file;
      if (fileSizeInMB > 5) {
        try {
          // Show compression info
          debugPrint('Compressing video: $fileName, original size: ${fileSizeInMB.toStringAsFixed(2)}MB');

          // Compress video
          final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            file.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );

          if (mediaInfo != null && mediaInfo.file != null) {
            videoFile = mediaInfo.file!;
            final int compressedSizeInBytes = await videoFile.length();
            final double compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
            debugPrint('Video compressed: ${compressedSizeInMB.toStringAsFixed(2)}MB (${(compressedSizeInMB / fileSizeInMB * 100).toStringAsFixed(0)}% of original)');
          } else {
            debugPrint('Video compression failed, using original file');
          }
        } catch (compressError) {
          debugPrint('Error compressing video: $compressError');
          // Continue with original file if compression fails
        }
      }

      // Create cloudinary file with proper settings
      final cloudinaryFile = CloudinaryFile.fromFile(
        videoFile.path,
        folder: 'notices/videos',
        resourceType: CloudinaryResourceType.Video,
      );

      // Upload with detailed error handling
      CloudinaryResponse response;
      try {
        response = await noticeCloudinary.uploadFile(cloudinaryFile);
        debugPrint('Video upload successful: ${response.secureUrl}');
      } catch (uploadError) {
        debugPrint('Cloudinary upload error details: $uploadError');
        throw Exception('Video upload failed: $uploadError');
      }

      return response.secureUrl;
    } catch (e) {
      debugPrint('Detailed video upload error: $e');
      throw Exception('Failed to upload notice video: $e');
    } finally {
      // Clear any resources used by VideoCompress
      try {
        await VideoCompress.cancelCompression();
      } catch (e) {
        // Ignore errors when canceling compression
      }
    }
  }

  // Helper method to print debug messages
  void debugPrint(String message) {
    // Use print in development, but in production you might want to use a logging framework
    print(message);
  }

  Future<String> uploadNoticeAttachment(File file) async {
    try {
      final String fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      const String folder = 'notices/attachments';

      // Check if file is a supported format (PDF, DOCX, or image)
      final List<String> supportedFormats = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif'];
      if (!supportedFormats.contains(fileExtension)) {
        throw Exception('Unsupported file format: $fileExtension. Supported formats are: ${supportedFormats.join(', ')}');
      }

      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: _getResourceType(fileExtension),
      );

      CloudinaryResponse response =
          await noticeCloudinary.uploadFile(cloudinaryFile);

      // For PDFs and documents, add dl=1 to force download
      if (['pdf', 'doc', 'docx'].contains(fileExtension)) {
        return '${response.secureUrl}?dl=1';
      }

      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload notice attachment: $e');
    }
  }

  CloudinaryResourceType _getResourceType(String fileExtension) {
    // For PDF and DOCX files, use Auto resource type
    if (['pdf', 'doc', 'docx'].contains(fileExtension)) {
      return CloudinaryResourceType.Auto;
    }
    // For image files, use Image resource type
    else if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      return CloudinaryResourceType.Image;
    }
    // For any other file types (which should be filtered out by validation)
    else {
      return CloudinaryResourceType.Auto;
    }
  }

  Future<String> uploadFile(File file) async {
    try {
      // Create a different Cloudinary instance for PDFs
      final isPdf = file.path.toLowerCase().endsWith('.pdf');
      final fileFolder = isPdf ? 'Admin_docs/pdfs' : 'Admin_docs';

      final targetCloudinary = adminCloudinary;

      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: fileFolder,
      );

      // Upload file
      CloudinaryResponse response =
          await targetCloudinary.uploadFile(cloudinaryFile);

      if (isPdf) {
        // For PDFs, add dl=1 to force download
        return '${response.secureUrl}?dl=1';
      }
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<String>> uploadFiles(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      String url = await uploadFile(file);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadReportImage(File file) async {
    try {
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'reports',
      );

      CloudinaryResponse response =
          await reportCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload report image: $e');
    }
  }

  Future<List<String>> uploadReportImages(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      String url = await uploadReportImage(file);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadReportVideo(File file) async {
    try {
      // Get file info
      final String fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      // Check if file is a supported video format
      final List<String> supportedFormats = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'];
      if (!supportedFormats.contains(fileExtension)) {
        throw Exception('Unsupported video format: $fileExtension. Supported formats are: ${supportedFormats.join(', ')}');
      }

      // Check file size
      final int fileSizeInBytes = await file.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // Compress video if it's larger than 5MB
      File videoFile = file;
      if (fileSizeInMB > 5) {
        try {
          // Show compression info
          debugPrint('Compressing report video: $fileName, original size: ${fileSizeInMB.toStringAsFixed(2)}MB');

          // Compress video
          final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            file.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );

          if (mediaInfo != null && mediaInfo.file != null) {
            videoFile = mediaInfo.file!;
            final int compressedSizeInBytes = await videoFile.length();
            final double compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
            debugPrint('Report video compressed: ${compressedSizeInMB.toStringAsFixed(2)}MB (${(compressedSizeInMB / fileSizeInMB * 100).toStringAsFixed(0)}% of original)');
          } else {
            debugPrint('Report video compression failed, using original file');
          }
        } catch (compressError) {
          debugPrint('Error compressing report video: $compressError');
          // Continue with original file if compression fails
        }
      }

      // Create cloudinary file with proper settings
      final cloudinaryFile = CloudinaryFile.fromFile(
        videoFile.path,
        folder: 'reports/videos',
        resourceType: CloudinaryResourceType.Video,
      );

      // Upload with detailed error handling
      CloudinaryResponse response;
      try {
        response = await reportCloudinary.uploadFile(cloudinaryFile);
        debugPrint('Report video upload successful: ${response.secureUrl}');
      } catch (uploadError) {
        debugPrint('Cloudinary report video upload error details: $uploadError');
        throw Exception('Report video upload failed: $uploadError');
      }

      return response.secureUrl;
    } catch (e) {
      debugPrint('Detailed report video upload error: $e');
      throw Exception('Failed to upload report video: $e');
    } finally {
      // Clear any resources used by VideoCompress
      try {
        await VideoCompress.cancelCompression();
      } catch (e) {
        // Ignore errors when canceling compression
      }
    }
  }

  Future<List<String>> uploadReportVideos(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      String url = await uploadReportVideo(file);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadProfileImage(File file) async {
    try {
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'profiles',
      );

      CloudinaryResponse response =
          await profileCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }
}
