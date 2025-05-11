import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'media_cache_service.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;

  late final CloudinaryPublic adminCloudinary;
  late final CloudinaryPublic marketCloudinary;
  late final CloudinaryPublic noticeCloudinary;
  late final CloudinaryPublic reportCloudinary;
  late final CloudinaryPublic profileCloudinary;

  CloudinaryService._internal() {
    adminCloudinary = CloudinaryPublic('dge8oi6ok', 'Admin_docs', cache: false);
    marketCloudinary =
        CloudinaryPublic('dge8oi6ok', 'market_images', cache: false);
    noticeCloudinary =
        CloudinaryPublic('dge8oi6ok', 'community_notices', cache: false);
    reportCloudinary =
        CloudinaryPublic('dge8oi6ok', 'community_reports', cache: false);
    profileCloudinary =
        CloudinaryPublic('dge8oi6ok', 'profile_images', cache: false);
  }

  Future<String> uploadMarketImage(File file) async {
    try {
      // Compress image before upload to reduce bandwidth
      final compressedFile = await _compressImage(file);

      final cloudinaryFile = CloudinaryFile.fromFile(
        compressedFile.path,
        folder: 'market',
      );

      CloudinaryResponse response =
          await marketCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      debugPrint('Failed to upload market image: $e');
      throw Exception('Failed to upload market image: $e');
    }
  }

  Future<List<String>> uploadMarketImages(List<File> files) async {
    List<String> urls = [];
    for (var file in files) {
      String url = await uploadMarketImage(file);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadNoticeImage(File file) async {
    try {
      // Compress image before upload to reduce bandwidth
      final compressedFile = await _compressImage(file);

      final cloudinaryFile = CloudinaryFile.fromFile(
        compressedFile.path,
        folder: 'notices',
      );

      CloudinaryResponse response =
          await noticeCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      debugPrint('Failed to upload notice image: $e');
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
    // Use Flutter's debugPrint which is automatically stripped in release mode
    if (kDebugMode) {
      print(message);
    }
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
      // Compress image before upload to reduce bandwidth
      final compressedFile = await _compressImage(file);

      final cloudinaryFile = CloudinaryFile.fromFile(
        compressedFile.path,
        folder: 'reports',
      );

      CloudinaryResponse response =
          await reportCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      debugPrint('Failed to upload report image: $e');
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
      // Compress image before upload to reduce bandwidth
      final compressedFile = await _compressImage(file);

      final cloudinaryFile = CloudinaryFile.fromFile(
        compressedFile.path,
        folder: 'profiles',
      );

      CloudinaryResponse response =
          await profileCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      debugPrint('Failed to upload profile image: $e');
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Optimize image URLs for bandwidth using the MediaCacheService
  String getOptimizedImageUrl(String originalUrl, {bool isListView = false}) {
    // Use the MediaCacheService for consistent optimization
    final mediaCacheService = MediaCacheService();
    return mediaCacheService.getOptimizedUrl(originalUrl, isListView: isListView);
  }

  // Optimize video URLs for bandwidth using the MediaCacheService
  String getOptimizedVideoUrl(String originalUrl, {bool isPreview = false}) {
    // Use the MediaCacheService for consistent optimization
    final mediaCacheService = MediaCacheService();
    return mediaCacheService.getOptimizedUrl(originalUrl, isVideo: true);
  }

  // Generate a lazy loading placeholder for images
  String getLazyLoadImageUrl(String originalUrl) {
    if (originalUrl.contains('cloudinary.com')) {
      // e_blur:1000 = extreme blur for placeholder
      // q_1 = very low quality (1%)
      // f_auto = automatic format
      // w_50 = tiny width for extremely fast loading
      if (originalUrl.contains('/upload/')) {
        return originalUrl.replaceFirst('/upload/', '/upload/e_blur:1000,q_1,f_auto,w_50/');
      }
    }
    return originalUrl;
  }

  // Generate a responsive image URL with srcset support
  String getResponsiveImageUrl(String originalUrl) {
    if (originalUrl.contains('cloudinary.com') && originalUrl.contains('/upload/')) {
      // w_auto = responsive width
      // c_scale = scale transformation
      // dpr_auto = automatic device pixel ratio
      // q_auto = automatic quality
      // f_auto = automatic format
      return originalUrl.replaceFirst('/upload/', '/upload/w_auto,c_scale,dpr_auto,q_auto,f_auto/');
    }
    return originalUrl;
  }

  // Compress image before upload to reduce bandwidth
  Future<File> _compressImage(File file) async {
    try {
      // Check if the file is an image
      final String fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      // Only compress image files
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        return file;
      }

      // Get file size
      final int fileSizeInBytes = await file.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      // Only compress if file is larger than 200KB
      if (fileSizeInMB < 0.2) {
        return file;
      }

      // Create a temporary file for the compressed image
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Determine compression quality based on file size
      int quality = 85; // Default quality
      if (fileSizeInMB > 5) {
        quality = 70; // More compression for very large images
      } else if (fileSizeInMB > 2) {
        quality = 80; // Medium compression for large images
      }

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        format: fileExtension == 'png' ? CompressFormat.png : CompressFormat.jpeg,
      );

      if (result != null) {
        // Log compression results
        final int compressedSizeInBytes = await result.length();
        final double compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
        debugPrint('Image compressed: ${compressedSizeInMB.toStringAsFixed(2)}MB (${(compressedSizeInMB / fileSizeInMB * 100).toStringAsFixed(0)}% of original)');

        return File(result.path);
      }
    } catch (e) {
      debugPrint('Error compressing image: $e');
    }

    // Return original file if compression fails
    return file;
  }
}
