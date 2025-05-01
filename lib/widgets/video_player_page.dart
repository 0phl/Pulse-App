import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/media_saver_service.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final VideoPlayerController? existingController;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.existingController,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  double _playbackSpeed = 1.0; // Used for restoring playback speed

  // For downloading and saving video
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  // Listen to video position changes to update UI
  void _setupPositionListener() {
    _videoPlayerController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Download and save the video to gallery
  Future<void> _downloadAndSaveVideo() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.videoUrl.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      // Download the video with progress tracking
      await Dio().download(
        widget.videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        // Save the video directly to gallery
        final mediaSaverService = MediaSaverService();
        await mediaSaverService.saveVideoToGallery(
          filePath: filePath,
          context: context,
          album: 'PULSE',
        );

        setState(() {
          _isDownloading = false;
        });

        // Clean up the temporary file
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (cleanupError) {
          debugPrint('Error cleaning up temporary file: $cleanupError');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading video: $e')),
        );
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // Use existing controller if provided, otherwise create a new one
      if (widget.existingController != null) {
        _videoPlayerController = widget.existingController!;

        // If the controller is already initialized, we can skip initialization
        if (_videoPlayerController.value.isInitialized) {
          _createChewieController();
          _setupPositionListener();

          if (mounted) {
            setState(() {
              _isInitialized = true;
              // Get the current playback speed
              _playbackSpeed = _videoPlayerController.value.playbackSpeed;
            });
          }
          return;
        }
      } else {
        // Create a new controller if none was provided
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }

      // Initialize the controller if needed
      await _videoPlayerController.initialize();

      _createChewieController();
      _setupPositionListener();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _createChewieController() {
    // Save current position if controller exists
    Duration? currentPosition;
    bool wasPlaying = false;
    if (_chewieController != null) {
      currentPosition = _videoPlayerController.value.position;
      wasPlaying = _videoPlayerController.value.isPlaying;
      _chewieController!.dispose();
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      // Only autoplay if the video was already playing
      autoPlay: _chewieController == null ? _videoPlayerController.value.isPlaying : wasPlaying,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                'Error playing video: $errorMessage',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        );
      },
      placeholder: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
        ),
      ),
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF00C49A),
        handleColor: const Color(0xFF00C49A),
        backgroundColor: Colors.grey.shade700,
        bufferedColor: Colors.grey.shade500,
      ),
      allowFullScreen: true,
      allowMuting: true,
      showControls: true, // Use built-in controls
      showControlsOnInitialize: true,
      hideControlsTimer: const Duration(seconds: 3),

    );

    // Restore position and playback speed if needed
    if (currentPosition != null) {
      _videoPlayerController.seekTo(currentPosition);
      if (wasPlaying) {
        _videoPlayerController.play();
      }
      // Ensure playback speed is maintained
      _videoPlayerController.setPlaybackSpeed(_playbackSpeed);
    }
  }





  @override
  void dispose() {
    // Only dispose the Chewie controller, not the underlying video controller
    if (_chewieController != null) {
      _chewieController!.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Video Player',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (!_isDownloading)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _downloadAndSaveVideo,
              tooltip: 'Download and Save Video',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          _hasError
              ? _buildErrorWidget()
              : _isInitialized
                  ? Center(
                      child: Chewie(controller: _chewieController!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                      ),
                    ),

          // Download progress overlay
          if (_isDownloading)
            Container(
              color: Colors.black.withAlpha(179),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Downloading video... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializePlayer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
