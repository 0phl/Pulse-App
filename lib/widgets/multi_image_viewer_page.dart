import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/media_saver_service.dart';

class MultiImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const MultiImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<MultiImageViewerPage> createState() => _MultiImageViewerPageState();
}

class _MultiImageViewerPageState extends State<MultiImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  // For downloading images
  bool _isDownloading = false;
  String? _tempFilePath;
  final MediaSaverService _mediaSaverService = MediaSaverService();
  final Map<int, String> _downloadedImages = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  // Download the current image
  Future<void> _downloadCurrentImage() async {
    final imageUrl = widget.imageUrls[_currentIndex];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'PULSE_temp_$timestamp.jpg';

    try {
      setState(() {
        _isDownloading = true;
      });

      // Check if we've already downloaded this image
      if (_downloadedImages.containsKey(_currentIndex)) {
        setState(() {
          _tempFilePath = _downloadedImages[_currentIndex];
          _isDownloading = false;
        });
        return;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Download the image
      await Dio().download(
        imageUrl,
        filePath,
      );

      if (mounted) {
        setState(() {
          _tempFilePath = filePath;
          _downloadedImages[_currentIndex] = filePath;
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

  // Save the current image to gallery
  Future<void> _saveCurrentImage({String? album}) async {
    if (_tempFilePath == null) {
      await _downloadCurrentImage();
    }

    if (_tempFilePath != null && mounted) {
      await _mediaSaverService.saveImageToGallery(
        filePath: _tempFilePath!,
        context: context,
        album: album ?? 'PULSE',
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () => _saveCurrentImage(album: 'PULSE'),
                  tooltip: 'Save to PULSE Album',
                ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(widget.imageUrls[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: '${widget.imageUrls[index]}_$index'),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.white70, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'Image could not be loaded',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 30.0,
                height: 30.0,
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                // Reset the temp file path when changing images
                _tempFilePath = _downloadedImages[index];
              });
            },
          ),

          // Loading overlay when downloading
          if (_isDownloading)
            Container(
              color: Colors.black.withAlpha(150),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Downloading image...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withAlpha(102),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
