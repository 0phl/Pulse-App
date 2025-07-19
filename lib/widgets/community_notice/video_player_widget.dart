import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/media_cache_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final mediaCacheService = MediaCacheService();
      final optimizedUrl = mediaCacheService.getOptimizedUrl(widget.videoUrl, isVideo: true);
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: false, // Disable autoplay to save bandwidth
        looping: false, // Disable looping to save bandwidth
        // when on mobile data
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        // Limit buffering to reduce bandwidth
        allowedScreenSleep: false,
        additionalOptions: (context) => [
          OptionItem(
            onTap: (context) => _toggleDataSaver(context),
            iconData: Icons.data_saver_on,
            title: 'Data Saver',
          ),
        ],
        // Disable autoInitialize to prevent preloading video
        autoInitialize: false,
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
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }



  // Toggle data saver mode
  void _toggleDataSaver(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isDataSaverOn = prefs.getBool('video_data_saver') ?? false;

    await prefs.setBool('video_data_saver', !isDataSaverOn);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isDataSaverOn
                ? 'Data saver mode enabled. Videos will use less data.'
                : 'Data saver mode disabled. Videos will use normal quality.'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Reinitialize player with new quality settings
    if (mounted) {
      _videoPlayerController.dispose();
      _chewieController?.dispose();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
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
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Container(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover, // Make the video cover the container
            child: SizedBox( // Constrain the Chewie widget to the video's size
              width: _videoPlayerController.value.size.width,
              height: _videoPlayerController.value.size.height,
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),
      ),
    );
  }
}

