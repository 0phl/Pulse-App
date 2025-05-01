import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'image_gallery_viewer.dart';
import 'video_player_page.dart';

class MediaGalleryWidget extends StatefulWidget {
  final List<String>? imageUrls;
  final String? videoUrl;
  final double height;

  const MediaGalleryWidget({
    super.key,
    this.imageUrls,
    this.videoUrl,
    this.height = 250,
  });

  @override
  State<MediaGalleryWidget> createState() => _MediaGalleryWidgetState();
}

class _MediaGalleryWidgetState extends State<MediaGalleryWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );

    if (widget.videoUrl != null) {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      await _videoPlayerController.initialize();

      // Get a safe aspect ratio (some videos might have extreme aspect ratios)
      double aspectRatio = _videoPlayerController.value.aspectRatio;

      // If aspect ratio is too extreme, use a more reasonable default
      if (aspectRatio < 0.5 || aspectRatio > 2.0) {
        aspectRatio = 16 / 9; // Default to standard video aspect ratio
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: aspectRatio,
        autoPlay: false, // Don't auto-play - let user decide when to play
        looping: true, // Loop the video for better user experience
        allowFullScreen: true, // Enable built-in fullscreen functionality
        allowMuting: true, // Allow muting
        showControls: true, // Show built-in controls
        showControlsOnInitialize: true, // Show controls immediately
        // Keep playing when navigating away
        routePageBuilder: null, // This ensures video continues playing in background
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 30),
                const SizedBox(height: 8),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        },
      );

      // Add listener to update UI when play state changes
      _videoPlayerController.addListener(() {
        if (mounted) {
          setState(() {
            // This will rebuild the UI when play state changes
          });
        }
      });

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasVideoError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.videoUrl != null) {
      _videoPlayerController.dispose();
      _chewieController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If there are no images and no video, return an empty container
    bool hasNoMedia = (widget.imageUrls == null || widget.imageUrls!.isEmpty) &&
                     widget.videoUrl == null;
    if (hasNoMedia) {
      return const SizedBox.shrink(); // Return empty widget when no media
    }

    // If there's only images, show the image gallery directly
    if (widget.imageUrls != null &&
        widget.imageUrls!.isNotEmpty &&
        widget.videoUrl == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ImageGalleryViewer(
            imageUrls: widget.imageUrls!,
            height: widget.imageUrls!.length > 1 ? 300 : widget.height, // Taller for multiple images
            // We'll let the ImageGalleryViewer determine the best fit based on image dimensions
            fit: BoxFit.cover,
            maxHeight: 500, // Increased maximum height for portrait images
            minHeight: 200, // Increased minimum height
            maintainAspectRatio: true,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    // If there's only a video, show the video player directly with proper constraints
    if (widget.videoUrl != null &&
        (widget.imageUrls == null || widget.imageUrls!.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: _buildVideoPlayer(),
      );
    }

    // If both exist, create a tabbed interface
    // Calculate a reasonable height for the tabbed interface
    final double tabHeight = widget.height - 40; // Subtract tab bar height

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 550, // Further increased maximum height for portrait media
        minHeight: 200,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        children: [
          // Tab bar with improved styling
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 18),
                      SizedBox(width: 6),
                      Text('Photos', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 18),
                      SizedBox(width: 6),
                      Text('Video', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
              labelColor: const Color(0xFF00C49A),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF00C49A),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(vertical: 10.0),
            ),
          ),
          const SizedBox(height: 8), // Slightly more spacing
          // Tab content (remaining height)
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11), // Slightly smaller to account for border
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 400, // Reduced max height for mixed media
                    minHeight: 150, // Reduced minimum height for small images
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Images tab
                      widget.imageUrls != null && widget.imageUrls!.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(4.0), // Minimal padding to reduce white space
                              child: ImageGalleryViewer(
                                imageUrls: widget.imageUrls!,
                                height: tabHeight,
                                fit: BoxFit.contain,
                                maxHeight: 400, // Consistent with container constraints
                                minHeight: 150, // Reduced minimum height for small images
                                maintainAspectRatio: true,
                                // Use MediaQuery to get the available width
                                width: MediaQuery.of(context).size.width - 32, // Account for padding
                                isInTabbedView: true, // Flag to indicate we're in tabbed view
                              ),
                            )
                          : Center(
                              child: Text(
                                'No images available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),

                      // Video tab
                      _buildVideoPlayer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // Build video player with consistent height constraints

    if (_hasVideoError) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                videoUrl: widget.videoUrl!,
                // Don't pass controller in error case since we need to reinitialize
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: 250, // Fixed height for error state
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 30),
                const SizedBox(height: 8),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to try again',
                  style: TextStyle(
                      color: Colors.blue[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isVideoInitialized) {
      return Container(
        width: double.infinity,
        height: 250, // Fixed height for loading state
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Calculate height based on aspect ratio but constrained
    final aspectRatio = _videoPlayerController.value.aspectRatio;

    // Determine if this is a portrait video
    final bool isPortrait = aspectRatio < 1.0;

    // Calculate appropriate height based on orientation
    double calculatedHeight;

    if (isPortrait) {
      // For portrait videos, use a taller height
      calculatedHeight = MediaQuery.of(context).size.width * 1.2; // Taller for portrait
    } else {
      // For landscape videos, calculate based on aspect ratio
      calculatedHeight = MediaQuery.of(context).size.width / aspectRatio;
    }

    // Clamp height to reasonable values
    final safeHeight = calculatedHeight.clamp(200.0, 400.0);

    return SizedBox(
      width: double.infinity,
      height: safeHeight,
      child: Chewie(controller: _chewieController!),
    );
  }
}
