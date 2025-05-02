import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/media_saver_service.dart';
import '../services/cloudinary_service.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;

  const ImageViewerPage({
    super.key,
    required this.imageUrl,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  bool _isDownloading = false;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    // Download the image to a temporary file when the page loads
    _downloadImage();
  }

  Future<void> _downloadImage() async {
    try {
      setState(() {
        _isDownloading = true;
      });

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'PULSE_temp_$timestamp.jpg';
      final filePath = '${tempDir.path}/$fileName';

      // Get high-quality version for download
      final cloudinaryService = CloudinaryService();
      final downloadUrl = cloudinaryService.getOptimizedImageUrl(widget.imageUrl, isListView: false);

      // Download the image
      await Dio().download(
        downloadUrl,
        filePath,
      );

      if (mounted) {
        setState(() {
          _tempFilePath = filePath;
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_tempFilePath != null)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () {
                if (_tempFilePath != null) {
                  final mediaSaverService = MediaSaverService();
                  mediaSaverService.saveImageToGallery(
                    filePath: _tempFilePath!,
                    context: context,
                    album: 'PULSE',
                  );
                }
              },
              tooltip: 'Save to PULSE Album',
            ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(
              // Use optimized URL for better performance and bandwidth savings
              CloudinaryService().getOptimizedImageUrl(widget.imageUrl, isListView: false)
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrl),
          ),
          if (_isDownloading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}