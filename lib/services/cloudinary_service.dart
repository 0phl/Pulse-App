import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

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
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'notices/videos',
        resourceType: CloudinaryResourceType.Video,
      );

      CloudinaryResponse response =
          await noticeCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload notice video: $e');
    }
  }

  Future<String> uploadNoticeAttachment(File file) async {
    try {
      final String fileName = file.path.split('/').last;
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      const String folder = 'notices/attachments';

      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: _getResourceType(fileExtension),
      );

      CloudinaryResponse response =
          await noticeCloudinary.uploadFile(cloudinaryFile);

      // For PDFs and other documents, add dl=1 to force download
      if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(fileExtension)) {
        return '${response.secureUrl}?dl=1';
      }

      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload notice attachment: $e');
    }
  }

  CloudinaryResourceType _getResourceType(String fileExtension) {
    if (['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'].contains(fileExtension)) {
      return CloudinaryResourceType.Video;
    } else if (['mp3', 'wav', 'ogg', 'aac', 'm4a'].contains(fileExtension)) {
      return CloudinaryResourceType.Auto;
    } else {
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
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: 'reports/videos',
        resourceType: CloudinaryResourceType.Video,
      );

      CloudinaryResponse response =
          await reportCloudinary.uploadFile(cloudinaryFile);
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload report video: $e');
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
