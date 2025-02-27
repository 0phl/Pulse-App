import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  
  late final CloudinaryPublic cloudinary;
  
  CloudinaryService._internal() {
    cloudinary = CloudinaryPublic('dy1jizr52', 'Admin_docs', cache: false);
  }

  Future<String> uploadFile(File file) async {
    try {
      // Create a different Cloudinary instance for PDFs
      final isPdf = file.path.toLowerCase().endsWith('.pdf');
      final fileFolder = isPdf ? 'Admin_docs/pdfs' : 'Admin_docs';
      
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        folder: fileFolder,
      );
      
      // Upload file
      CloudinaryResponse response = await cloudinary.uploadFile(cloudinaryFile);
      
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
}
