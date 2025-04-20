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

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: false,
        looping: false,
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
    // If there's only images, show the image gallery directly
    if (widget.imageUrls != null &&
        widget.imageUrls!.isNotEmpty &&
        widget.videoUrl == null) {
      return ImageGalleryViewer(
        imageUrls: widget.imageUrls!,
        height: widget.height,
      );
    }

    // If there's only a video, show the video player directly
    if (widget.videoUrl != null &&
        (widget.imageUrls == null || widget.imageUrls!.isEmpty)) {
      return _buildVideoPlayer();
    }

    // If both exist, create a tabbed interface
    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          // Tab bar (about 40px)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 16),
                      SizedBox(width: 4),
                      Text('Photos'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 16),
                      SizedBox(width: 4),
                      Text('Video'),
                    ],
                  ),
                ),
              ],
              labelColor: const Color(0xFF00C49A),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF00C49A),
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          const SizedBox(height: 8),
          // Tab content (remaining height)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Images tab
                widget.imageUrls != null && widget.imageUrls!.isNotEmpty
                    ? ImageGalleryViewer(
                        imageUrls: widget.imageUrls!,
                        height: double.infinity,
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
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasVideoError) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(videoUrl: widget.videoUrl!),
            ),
          );
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerPage(videoUrl: widget.videoUrl!),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _videoPlayerController.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      ),
    );
  }
}
