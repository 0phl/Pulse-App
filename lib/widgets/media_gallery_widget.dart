import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      // Get the video's natural aspect ratio
      double aspectRatio = _videoPlayerController.value.aspectRatio;

      // If aspect ratio is too extreme, use a more reasonable default
      if (aspectRatio < 0.5 || aspectRatio > 2.0) {
        final bool isPortrait = aspectRatio < 1.0;
        aspectRatio = isPortrait ? 9 / 16 : 16 / 9;
      }

      // For portrait videos, we'll let the layout builder handle the aspect ratio
      // to prevent overflow issues. For landscape, we'll use the natural aspect ratio.
      final bool isPortrait = aspectRatio < 1.0;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        // For portrait videos, use null to let the layout builder handle sizing
        // For landscape videos, use the natural aspect ratio
        aspectRatio: isPortrait ? null : aspectRatio,
        autoPlay: false, // Don't auto-play - let user decide when to play
        looping: false, // Don't loop the video - stop when it finishes
        allowFullScreen: true, // Enable built-in fullscreen functionality
        allowMuting: true, // Allow muting
        showControls: true, // Show built-in controls
        showControlsOnInitialize: true, // Show controls immediately for better discoverability
        hideControlsTimer: const Duration(seconds: 5), // Hide controls after 5 seconds of inactivity
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp], // Return to portrait after fullscreen
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF00C49A),
          handleColor: const Color(0xFF00C49A),
          backgroundColor: Colors.grey.shade300,
          bufferedColor: Colors.grey.shade500,
        ),
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            ),
          ),
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
        maxHeight: 500, // Reduced maximum height for more compact appearance
        minHeight: 180, // Reduced minimum height
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        children: [
          // Modern, minimalist tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            height: 36, // Reduced height for more compact appearance
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20), // More rounded corners
              border: Border.all(color: Colors.grey[200]!, width: 0.5), // Thinner border
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 14), // Smaller icon
                      SizedBox(width: 4), // Reduced spacing
                      Text('Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), // Smaller text
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 14), // Smaller icon
                      SizedBox(width: 4), // Reduced spacing
                      Text('Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), // Smaller text
                    ],
                  ),
                ),
              ],
              labelColor: const Color(0xFF00C49A),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFF00C49A),
              indicatorSize: TabBarIndicatorSize.label, // Smaller indicator
              indicatorWeight: 2, // Thinner indicator
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8), // Reduced padding
              padding: EdgeInsets.zero, // Remove default padding
            ),
          ),
          const SizedBox(height: 4), // Minimal spacing for compact design
          // Tab content (remaining height)
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 0.5), // Thinner, lighter border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.5), // Slightly smaller to account for border
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 380, // Slightly reduced max height for mixed media
                    minHeight: 140, // Slightly reduced minimum height for small images
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
                                fit: BoxFit.cover, // Changed to cover to fill container
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
    // Build video player with consistent height constraints and improved styling

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
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.black,
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Error loading video',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Tap to try again',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C49A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Loading video...',
                  style: TextStyle(
                    color: Color(0xFF00C49A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For community notices, we want videos to be prominent with consistent appearance
    // Use a height that works well for all video orientations
    double safeHeight = 350.0; // Default height for videos

    // Adjust height for portrait videos to provide more vertical space
    if (_videoPlayerController.value.isInitialized) {
      final aspectRatio = _videoPlayerController.value.aspectRatio;
      if (aspectRatio < 1.0) {
        // For portrait videos, use a taller container
        safeHeight = 400.0;
      }
    }

    return Container(
      width: double.infinity,
      height: safeHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // Slightly smaller to account for border
        child: Stack(
          children: [
            // Video player with proper sizing that fills container without stretching
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Get video aspect ratio
                    final aspectRatio = _videoPlayerController.value.aspectRatio;

                    // Calculate the size that maintains aspect ratio within constraints
                    double targetWidth, targetHeight;

                    // Check if this is a small video (width or height less than 400px)
                    final bool isSmallVideo = _videoPlayerController.value.size.width < 400 ||
                                             _videoPlayerController.value.size.height < 400;

                    if (aspectRatio < 1.0) {
                      // Portrait video - constrain by width first to prevent horizontal overflow
                      // Add a small buffer (4px) to ensure it never overflows
                      targetWidth = constraints.maxWidth - 4;
                      targetHeight = targetWidth / aspectRatio;
                    } else {
                      // Landscape video - constrain by width
                      targetWidth = constraints.maxWidth;
                      targetHeight = targetWidth / aspectRatio;

                      // For small landscape videos, ensure they fill more of the available space
                      if (isSmallVideo && targetHeight < constraints.maxHeight * 0.7) {
                        // Scale up small videos to at least 70% of container height
                        targetHeight = constraints.maxHeight * 0.7;
                        targetWidth = targetHeight * aspectRatio;
                      }
                    }

                    // Ensure we don't exceed container bounds
                    if (targetHeight > constraints.maxHeight) {
                      targetHeight = constraints.maxHeight;
                      targetWidth = targetHeight * aspectRatio;

                      // Double-check width doesn't exceed constraints after height adjustment
                      if (targetWidth > constraints.maxWidth - 4) {
                        targetWidth = constraints.maxWidth - 4;
                      }
                    }

                    return Center(
                      child: Container(
                        width: targetWidth,
                        height: targetHeight,
                        color: Colors.black, // Add black background to ensure no white letterboxing
                        child: Chewie(controller: _chewieController!),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Gradient overlay for better control visibility
            if (!_videoPlayerController.value.isPlaying)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.3),
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
              ),

            // Custom play button overlay when paused
            if (!_videoPlayerController.value.isPlaying)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _videoPlayerController.play();
                  },
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
