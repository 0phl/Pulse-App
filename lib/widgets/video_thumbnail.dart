import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:cached_network_image/cached_network_image.dart';

class VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      // First check if the video URL has a thumbnail URL variant
      // Some services like Cloudinary provide thumbnail URLs
      final thumbnailUrl = _getThumbnailUrlFromVideoUrl(widget.videoUrl);
      if (thumbnailUrl != null) {
        // If we have a direct thumbnail URL, we'll use CachedNetworkImage instead
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Otherwise generate thumbnail from video
      try {
        final bytes = await vt.VideoThumbnail.thumbnailData(
          video: widget.videoUrl,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 300,
          quality: 50,
          timeMs: 1000, // Get thumbnail from 1 second into the video
        );

        if (mounted) {
          setState(() {
            _thumbnailBytes = bytes;
            _isLoading = false;
          });
        }
      } catch (thumbnailError) {
        // Try a different approach for Cloudinary videos
        if (widget.videoUrl.contains('cloudinary.com')) {
          // The alternative approaches will be tried in the build method
          // through the error handler of CachedNetworkImage
        }

        // Continue with error state, but we'll try alternative approaches in the build method
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  // Try to extract a thumbnail URL from video URL (for services like Cloudinary)
  String? _getThumbnailUrlFromVideoUrl(String videoUrl) {
    // Check if it's a Cloudinary URL
    if (videoUrl.contains('cloudinary.com')) {
      try {
        // Method 1: For videos with explicit extensions, replace with jpg
        if (videoUrl.endsWith('.mp4') || videoUrl.endsWith('.mov')) {
          final thumbnailUrl = '${videoUrl.substring(0, videoUrl.lastIndexOf('.'))}.jpg';
          return thumbnailUrl;
        }

        // Method 2: For Cloudinary URLs without explicit extensions
        final uri = Uri.parse(videoUrl);
        final pathSegments = uri.pathSegments;

        // Find the upload segment index
        final uploadIndex = pathSegments.indexOf('upload');
        if (uploadIndex >= 0 && uploadIndex < pathSegments.length - 1) {
          // Use video thumbnail transformation
          final newPathSegments = List<String>.from(pathSegments);
          newPathSegments.insert(uploadIndex + 1, 'c_thumb,w_300,h_200');
          return uri.replace(pathSegments: newPathSegments).toString();
        }

        // Method 3: Try to extract video ID and use a direct thumbnail URL
        // This is specific to Cloudinary's URL structure
        final regex = RegExp(r'v(\d+)/([^/]+)');
        final match = regex.firstMatch(videoUrl);
        if (match != null && match.groupCount >= 2) {
          final videoId = match.group(2);
          return 'https://res.cloudinary.com/dy1jizr52/video/upload/c_thumb,w_300,h_200/$videoId.jpg';
        }
      } catch (e) {
        // Silently handle errors and try next approach
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnailWidget(),
            ),

            // Play icon overlay
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const Positioned(
                bottom: 8,
                right: 8,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailWidget() {
    // If we have a Cloudinary or other direct thumbnail URL
    final thumbnailUrl = _getThumbnailUrlFromVideoUrl(widget.videoUrl);

    if (thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.movie_outlined, color: Colors.grey[400], size: 40),
          ),
        ),
        errorWidget: (context, url, error) {
          // Try an alternative thumbnail URL format if the first one fails
          if (url.contains('cloudinary.com') && !url.contains('c_fill')) {
            // Try a different transformation
            final uri = Uri.parse(url);
            final pathSegments = uri.pathSegments;
            final uploadIndex = pathSegments.indexOf('upload');

            if (uploadIndex >= 0 && uploadIndex < pathSegments.length - 1) {
              final newPathSegments = List<String>.from(pathSegments);
              // Use a different transformation
              newPathSegments.insert(uploadIndex + 1, 'w_300,h_200,c_fill,g_auto');

              final alternativeThumbnailUrl = uri.replace(
                pathSegments: newPathSegments,
              ).toString();

              // Return a new CachedNetworkImage with the alternative URL
              return CachedNetworkImage(
                imageUrl: alternativeThumbnailUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.movie_outlined, color: Colors.grey[400], size: 40),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.error_outline, color: Colors.grey[400], size: 40),
                  ),
                ),
              );
            }
          }

          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(Icons.error_outline, color: Colors.grey[400], size: 40),
            ),
          );
        },
      );
    }

    // If we have generated thumbnail bytes
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Fallback placeholder
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: _hasError
            ? Icon(Icons.error_outline, color: Colors.grey[400], size: 40)
            : Icon(Icons.movie_outlined, color: Colors.grey[400], size: 40),
      ),
    );
  }
}
