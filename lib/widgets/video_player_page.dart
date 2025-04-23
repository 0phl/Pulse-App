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

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
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
  bool _showCustomOverlay = false;
  Timer? _overlayTimer;
  double _playbackSpeed = 1.0;
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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
      if (_showCustomOverlay && mounted) {
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
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

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
      autoPlay: _chewieController == null ? true : wasPlaying,
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
      showControls: false, // Hide default controls
      showControlsOnInitialize: false,
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

  void _toggleOverlay() {
    setState(() {
      _showCustomOverlay = !_showCustomOverlay;
    });

    // Auto-hide overlay after a few seconds
    _overlayTimer?.cancel();
    if (_showCustomOverlay) {
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showCustomOverlay = false;
          });
        }
      });
    }
  }

  Widget _buildCustomOverlay() {
    final duration = _videoPlayerController.value.duration;
    final position = _videoPlayerController.value.position;
    final progress = position.inMilliseconds / duration.inMilliseconds;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: Container(
          color: Colors.black.withAlpha(102), // 0.4 opacity
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Empty space at top
              const SizedBox(),

              // Center controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(
                      Icons.replay_5,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final newPosition = _videoPlayerController.value.position - const Duration(seconds: 5);
                      _videoPlayerController.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
                    },
                  ),
                  IconButton(
                    iconSize: 64,
                    icon: Icon(
                      _videoPlayerController.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_videoPlayerController.value.isPlaying) {
                        _videoPlayerController.pause();
                      } else {
                        _videoPlayerController.play();
                      }
                      setState(() {});
                    },
                  ),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(
                      Icons.forward_5,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final newPosition = _videoPlayerController.value.position + const Duration(seconds: 5);
                      final duration = _videoPlayerController.value.duration;
                      _videoPlayerController.seekTo(newPosition > duration ? duration : newPosition);
                    },
                  ),
                ],
              ),

              // Progress bar at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0, left: 16.0, right: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: const Color(0xFF00C49A),
                        inactiveTrackColor: Colors.grey.shade700,
                        thumbColor: const Color(0xFF00C49A),
                        overlayColor: const Color(0xFF00C49A).withAlpha(60),
                      ),
                      child: Slider(
                        value: progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          final newPosition = Duration(milliseconds: (value * duration.inMilliseconds).round());
                          _videoPlayerController.seekTo(newPosition);
                        },
                      ),
                    ),

                    // Time indicators and playback speed
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: _changePlaybackSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _changePlaybackSpeed() {
    setState(() {
      // Find the next speed in the list
      int currentIndex = _availableSpeeds.indexOf(_playbackSpeed);
      int nextIndex = (currentIndex + 1) % _availableSpeeds.length;
      _playbackSpeed = _availableSpeeds[nextIndex];

      // Apply the new speed to the video player
      _videoPlayerController.setPlaybackSpeed(_playbackSpeed);
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _overlayTimer?.cancel();
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
                  ? Stack(
                      children: [
                        GestureDetector(
                          onTap: _toggleOverlay,
                          child: Chewie(controller: _chewieController!),
                        ),
                        if (_showCustomOverlay)
                          _buildCustomOverlay(),
                      ],
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
