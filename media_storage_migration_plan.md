# Media Storage Optimization and Migration Plan

## Overview

This document outlines a strategic plan to optimize Cloudinary usage and potentially migrate to a hybrid multi-service approach for media storage and delivery. The goal is to stay within free tier limits while maintaining high performance and reliability.

## Current Situation

- **Current Provider**: Cloudinary
- **Free Tier Limit**: 25GB storage and bandwidth
- **Current Usage**:
  - Bandwidth: 26.75 GB (exceeding free tier)
  - Storage: 178.29 MB (well under free tier)
  - Assets: 182 images & videos
  - Transformations: 380
  - Image Impressions: 11.32K
- **Primary Issue**: Bandwidth consumption exceeding free tier, not storage
- **App Requirements**: Image storage, video hosting, document storage, media transformations

## Strategic Approach: Optimization First, Migration If Needed

Given that storage usage is minimal (178.29 MB) and the bandwidth is only slightly over the free tier limit (26.75 GB vs 25 GB), we'll implement a two-track approach:

1. **Track 1: Optimize Cloudinary Usage** - Implement bandwidth-saving techniques to stay within free tier
2. **Track 2: Prepare for Migration** - Set up alternative services only if optimization isn't sufficient

### Phase 1: Cloudinary Optimization (1-2 weeks)

1. **Enhance Media Transformations**
   - Convert all images to WebP format (30-50% smaller files)
   - Apply quality reduction to 80% (minimal visual impact)
   - Resize images to appropriate dimensions for each view
   - Implement responsive images with srcset

2. **Implement Aggressive Caching**
   - Enhance the MediaCacheService
   - Increase cache duration to 14+ days
   - Implement network-aware caching strategies
   - Pre-load frequently accessed images

3. **Optimize Video Delivery**
   - Use adaptive bitrate streaming for videos
   - Implement video compression before upload
   - Use thumbnail-only loading until play is clicked
   - Disable autoplay and looping

4. **Monitor Bandwidth Usage**
   - Implement analytics to track bandwidth consumption
   - Identify high-bandwidth assets
   - Set up alerts for approaching limits

### Phase 2: Targeted Migration (Only If Needed)

If optimization doesn't bring usage under 25GB, implement a targeted migration approach:

1. **Identify Top Bandwidth Consumers**
   - Analyze which specific assets consume the most bandwidth
   - Focus only on migrating these high-impact assets
   - Create a "bandwidth budget" for each service

2. **Set up Backblaze B2 + Bunny.net for High-Bandwidth Content**
   - Backblaze B2: 10GB free storage
   - Bunny.net: $5 free credit (~500GB bandwidth)
   - Migrate only videos and frequently accessed images

3. **Update References for Migrated Content**
   - Modify URLs in the database only for migrated assets
   - Keep most content on Cloudinary

### Phase 3: Full Hybrid Approach (Only If Bandwidth Continues to Grow)

If your app's usage grows significantly beyond what optimization can handle:

1. **Implement Content Type Specialization**

   | Content Type | Service | Free Tier |
   |--------------|---------|-----------|
   | Videos | Backblaze B2 + Bunny.net | 10GB storage, $5 credit |
   | High-traffic Images | ImageKit | 20GB bandwidth/month |
   | Low-traffic Content | Cloudinary | Portion of 25GB bandwidth |
   | New Uploads | Based on content type | Various |

2. **Create a Media Router Service**
   - Route requests to appropriate service based on content type
   - Implement transparent URL handling

## Implementation Details

### 1. Enhanced CloudinaryService

```dart
class CloudinaryService {
  // Cloudinary configuration
  final String _cloudName = 'your_cloud_name';
  final String _apiKey = 'your_api_key';
  final String _apiSecret = 'your_api_secret';

  // Cloudinary instance
  final cloudinary = CloudinaryPublic('your_cloud_name', 'your_upload_preset');

  // Upload an image with optimization
  Future<String> uploadImage(File file, {String folder = 'images'}) async {
    try {
      // Compress image before upload
      final compressedFile = await _compressImage(file);

      // Upload to Cloudinary with optimization flags
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      rethrow;
    }
  }

  // Upload a video with optimization
  Future<String> uploadVideo(File file, {String folder = 'videos'}) async {
    try {
      // Compress video before upload
      final compressedFile = await _compressVideo(file);

      // Upload to Cloudinary with optimization flags
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          compressedFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      rethrow;
    }
  }

  // Get optimized URL for images or videos
  String getOptimizedUrl(String originalUrl, {bool isListView = false, bool isVideo = false}) {
    if (!originalUrl.contains('cloudinary.com')) return originalUrl;

    // Don't modify URLs that already have transformations
    if (originalUrl.contains('/upload/q_') ||
        originalUrl.contains('/upload/w_') ||
        originalUrl.contains('/upload/f_')) {
      return originalUrl;
    }

    if (isVideo) {
      // Video optimization
      return originalUrl.replaceFirst(
        '/upload/',
        '/upload/q_auto,vc_auto,so_0/'
      );
    } else {
      // Image optimization
      if (isListView) {
        // List view - smaller images
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_300,c_limit,q_auto:good,f_auto/'
        );
      } else {
        // Detail view - larger images
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_800,c_limit,q_auto:good,f_auto/'
        );
      }
    }
  }

  // Generate a responsive image URL with srcset support
  String getResponsiveImageUrl(String originalUrl) {
    if (originalUrl.contains('cloudinary.com') && originalUrl.contains('/upload/')) {
      // w_auto = responsive width
      // c_scale = scale transformation
      // dpr_auto = automatic device pixel ratio
      // q_auto = automatic quality
      // f_auto = automatic format
      return originalUrl.replaceFirst(
        '/upload/',
        '/upload/w_auto,c_scale,dpr_auto,q_auto,f_auto/'
      );
    }
    return originalUrl;
  }

  // Helper methods for compression
  Future<File> _compressImage(File file) async {
    // Implementation for image compression
    // Use flutter_image_compress or similar
    return file; // Placeholder
  }

  Future<File> _compressVideo(File file) async {
    // Implementation for video compression
    // Use video_compress or similar
    return file; // Placeholder
  }
}
```

### 2. Enhanced Media Cache Service

```dart
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  // Cache configuration
  static const int maxCacheSizeMb = 300; // Increased to 300MB max cache
  static const int cacheDurationDays = 30; // Increased to 30 days for rarely changing media
  static const bool enableAggressiveCaching = true;

  // Network type tracking
  bool _isMeteredConnection = true;

  // Initialize connectivity monitoring
  Future<void> initConnectivityMonitoring() async {
    try {
      // Get initial connectivity status
      final connectivityResult = await Connectivity().checkConnectivity();

      // Consider mobile connections as metered
      _isMeteredConnection = connectivityResult.contains(ConnectivityResult.mobile);

      // Listen for connectivity changes
      Connectivity().onConnectivityChanged.listen((result) {
        _isMeteredConnection = result.contains(ConnectivityResult.mobile);
      });
    } catch (e) {
      debugPrint('Error initializing connectivity monitoring: $e');
      // Default to assuming metered connection for safety
      _isMeteredConnection = true;
    }
  }

  // Optimize Cloudinary URL based on network conditions and view type
  String getOptimizedUrl(String originalUrl, {bool isListView = false, bool isVideo = false}) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl;
    }

    // Don't modify URLs that already have transformations
    if (originalUrl.contains('/upload/q_') ||
        originalUrl.contains('/upload/w_') ||
        originalUrl.contains('/upload/f_')) {
      return originalUrl;
    }

    // Apply different optimizations based on connection type
    if (_isMeteredConnection) {
      // On mobile data - aggressive optimization
      if (isVideo) {
        // Videos - very low quality on mobile data
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/q_auto:low,vc_auto,so_0/'
        );
      } else if (isListView) {
        // List view images - very small and low quality
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_200,c_limit,q_auto:low,f_auto/'
        );
      } else {
        // Detail view images - medium quality
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_600,c_limit,q_auto:eco,f_auto/'
        );
      }
    } else {
      // On WiFi - better quality but still optimized
      if (isVideo) {
        // Videos - medium quality on WiFi
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/q_auto,vc_auto/'
        );
      } else if (isListView) {
        // List view images - small but decent quality
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_300,c_limit,q_auto,f_auto/'
        );
      } else {
        // Detail view images - good quality
        return originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_800,c_limit,q_auto,f_auto/'
        );
      }
    }
  }

  // Get cached file or download and cache
  Future<String> getCachedMediaUrl(String originalUrl) async {
    try {
      // First, optimize the URL based on network conditions
      final optimizedUrl = getOptimizedUrl(originalUrl);

      // Generate cache key from original URL (not optimized) to maintain consistency
      final cacheKey = _generateCacheKey(originalUrl);

      // Check if file exists in cache
      final cacheDir = await _getCacheDirectory();
      final cachedFile = File('${cacheDir.path}/$cacheKey');

      if (await cachedFile.exists()) {
        // Check if cache is still valid
        final fileStats = await cachedFile.stat();
        final fileAge = DateTime.now().difference(fileStats.modified);

        if (fileAge.inDays < cacheDurationDays) {
          // Cache hit - return local file URL
          return cachedFile.path;
        }
      }

      // Check connectivity before downloading
      bool isOnMobileData = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        isOnMobileData = connectivityResult.contains(ConnectivityResult.mobile);
      } catch (e) {
        // If we can't check connectivity, assume we're on WiFi
        isOnMobileData = false;
      }

      // If on mobile data and aggressive caching is enabled, avoid downloading large files
      if (enableAggressiveCaching &&
          isOnMobileData &&
          !_shouldDownloadOnMobileData(originalUrl)) {
        // Return optimized URL instead of downloading
        return optimizedUrl;
      }

      // Cache miss or expired - download and cache
      final response = await http.get(Uri.parse(optimizedUrl));
      if (response.statusCode == 200) {
        await cachedFile.writeAsBytes(response.bodyBytes);

        // Update cache size tracking
        await _updateCacheSize(response.bodyBytes.length);

        return cachedFile.path;
      }
    } catch (e) {
      debugPrint('Media cache error: $e');
    }

    // Fallback to optimized URL if caching fails
    return getOptimizedUrl(originalUrl);
  }
}
```

### 3. Video Player Optimization

```dart
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isDataSaverEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadDataSaverPreference();
    _initializePlayer();
  }

  Future<void> _loadDataSaverPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDataSaverEnabled = prefs.getBool('video_data_saver') ?? false;
    });
  }

  Future<void> _initializePlayer() async {
    try {
      // Use the MediaCacheService to optimize video URL based on network conditions
      final mediaCacheService = MediaCacheService();
      final optimizedUrl = mediaCacheService.getOptimizedUrl(widget.videoUrl, isVideo: true);

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: widget.autoPlay,
        looping: false, // Disable looping
        showControls: true,
        placeholder: Center(child: CircularProgressIndicator()),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
        additionalOptions: (context) => [
          OptionItem(
            onTap: (context) => _toggleDataSaver(context),
            iconData: Icons.data_saver_on,
            title: 'Data Saver',
          ),
        ],
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  void _toggleDataSaver(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isDataSaverOn = prefs.getBool('video_data_saver') ?? false;

    await prefs.setBool('video_data_saver', !isDataSaverOn);

    // Show a confirmation message
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
    return _isInitialized
        ? Chewie(controller: _chewieController!)
        : Container(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
  }
}
```

## Cloudinary Optimization Techniques

### URL Transformation Parameters

Cloudinary offers powerful URL-based transformations that can significantly reduce bandwidth:

| Parameter | Description | Example | Bandwidth Savings |
|-----------|-------------|---------|------------------|
| `f_auto` | Automatic format selection (WebP for supported browsers) | `/upload/f_auto/` | 30-50% |
| `q_auto:eco` | Automatic quality with eco setting | `/upload/q_auto:eco/` | 30-40% |
| `w_800` | Resize width to 800px | `/upload/w_800/` | 40-70% |
| `c_limit` | Resize only if larger than specified dimensions | `/upload/w_800,c_limit/` | Varies |
| `dpr_auto` | Automatic device pixel ratio | `/upload/dpr_auto/` | 20-50% |
| `vc_auto` | Automatic video codec selection | `/upload/vc_auto/` | 30-50% |
| `so_0` | Start video offset at 0 seconds | `/upload/so_0/` | Varies |

### Recommended Transformation Combinations

1. **List View Images**:
   ```
   /upload/w_300,c_limit,q_auto:eco,f_auto/
   ```

2. **Detail View Images**:
   ```
   /upload/w_800,c_limit,q_auto:good,f_auto/
   ```

3. **Video Thumbnails**:
   ```
   /upload/w_300,h_200,c_fill,q_auto:eco,f_auto/
   ```

4. **Video Playback**:
   ```
   /upload/q_auto,vc_auto,so_0/
   ```

5. **Responsive Images**:
   ```
   /upload/w_auto,c_scale,dpr_auto,q_auto,f_auto/
   ```

## Implementation Checklist

### Phase 1: Optimization (1-2 weeks)

- [ ] Update CloudinaryService with optimized URL transformations
- [ ] Enhance MediaCacheService with network-aware caching
- [ ] Implement connectivity monitoring
- [ ] Update video player to disable looping
- [ ] Add data saver mode for videos
- [ ] Implement image compression before upload
- [ ] Implement video compression before upload
- [ ] Set up bandwidth monitoring

### Phase 2: Targeted Migration (Only If Needed)

- [ ] Analyze Cloudinary usage to identify high-bandwidth assets
- [ ] Set up Backblaze B2 account and bucket (if needed)
- [ ] Set up Bunny.net account and pull zone (if needed)
- [ ] Implement B2BunnyService for high-bandwidth content
- [ ] Update database references for migrated content

## Expected Results

By implementing the optimization techniques in Phase 1, we expect to:

1. **Reduce bandwidth usage by 40-60%** (from 26.75GB to ~13-16GB)
2. **Stay within the Cloudinary free tier** (25GB bandwidth)
3. **Improve app performance** with faster loading times
4. **Reduce mobile data usage** for users

If optimization alone doesn't bring usage under the free tier limit, the targeted migration in Phase 2 will address the remaining overage.

## Conclusion

This optimization-first approach provides:
1. **Immediate bandwidth reduction** without complex migration
2. **Better user experience** with faster loading and reduced data usage
3. **Simplified implementation** by focusing on optimization first
4. **Fallback migration plan** if optimization isn't sufficient

By implementing these optimizations, we can likely stay within Cloudinary's free tier while maintaining high-quality media delivery for our users.
