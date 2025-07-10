import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  // Cache configuration
  static const int maxCacheSizeMb = 300; // Increased to 300MB max cache
  static const int cacheDurationDays = 30; // Increased to 30 days for rarely changing media
  static const bool enableAggressiveCaching = true; // Enable aggressive caching

  // Network type tracking
  bool _isMeteredConnection = true;

  Future<void> initConnectivityMonitoring() async {
    try {
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

    // Base path replacement
    String optimizedUrl = originalUrl;

    // Apply different optimizations based on connection type
    if (_isMeteredConnection) {
      // On mobile data - aggressive optimization
      if (isVideo) {
        // Videos - very low quality on mobile data
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/q_auto:low,vc_auto,so_0,c_limit,h_720/'
        );
      } else if (isListView) {
        // List view images - very small and low quality
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_200,c_limit,q_auto:low,f_auto,dpr_auto/'
        );
      } else {
        // Detail view images - medium quality
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_600,c_limit,q_auto:eco,f_auto,dpr_auto/'
        );
      }
    } else {
      // On WiFi - better quality but still optimized
      if (isVideo) {
        // Videos - medium quality on WiFi
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/q_auto:good,vc_auto,c_limit,h_1080/'
        );
      } else if (isListView) {
        // List view images - small but decent quality
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_300,c_limit,q_auto:good,f_auto,dpr_auto/'
        );
      } else {
        // Detail view images - good quality
        optimizedUrl = originalUrl.replaceFirst(
          '/upload/',
          '/upload/w_800,c_limit,q_auto:good,f_auto,dpr_auto/'
        );
      }
    }

    return optimizedUrl;
  }

  Future<String> getCachedMediaUrl(String originalUrl) async {
    try {
      // First, optimize the URL based on network conditions
      final optimizedUrl = getOptimizedUrl(originalUrl);

      // Generate cache key from original URL (not optimized) to maintain consistency
      final cacheKey = _generateCacheKey(originalUrl);

      final cacheDir = await _getCacheDirectory();
      final cachedFile = File('${cacheDir.path}/$cacheKey');

      if (await cachedFile.exists()) {
        final fileStats = await cachedFile.stat();
        final fileAge = DateTime.now().difference(fileStats.modified);

        if (fileAge.inDays < cacheDurationDays) {
          // Cache hit - return local file URL
          return cachedFile.path;
        }
      }

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
        return optimizedUrl;
      }

      // Cache miss or expired - download and cache
      final response = await http.get(Uri.parse(optimizedUrl));
      if (response.statusCode == 200) {
        await cachedFile.writeAsBytes(response.bodyBytes);

        await _updateCacheSize(response.bodyBytes.length);

        return cachedFile.path;
      }
    } catch (e) {
      debugPrint('Media cache error: $e');
    }

    // Fallback to optimized URL if caching fails
    return getOptimizedUrl(originalUrl);
  }

  // Determine if we should download on mobile data
  bool _shouldDownloadOnMobileData(String url) {
    // Don't download videos on mobile data
    if (url.contains('.mp4') || url.contains('.mov') || url.contains('.avi')) {
      return false;
    }

    // Don't download high-res images on mobile data
    if (url.contains('cloudinary.com') && !url.contains('w_')) {
      return false; // Avoid downloading original size images
    }

    return true;
  }

  // Generate a unique cache key from URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Directory> _getCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final mediaCacheDir = Directory('${cacheDir.path}/media_cache');

    if (!await mediaCacheDir.exists()) {
      await mediaCacheDir.create(recursive: true);
    }

    return mediaCacheDir;
  }

  Future<void> _updateCacheSize(int newBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSize = prefs.getInt('media_cache_size_bytes') ?? 0;
      final newSize = currentSize + newBytes;

      await prefs.setInt('media_cache_size_bytes', newSize);

      if (newSize > maxCacheSizeMb * 1024 * 1024) {
        _cleanupCache();
      }
    } catch (e) {
      debugPrint('Error updating cache size: $e');
    }
  }

  // Clean up old cache files
  Future<void> _cleanupCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();

      // Sort files by modification time (oldest first)
      files.sort((a, b) {
        if (a is File && b is File) {
          return a.statSync().modified.compareTo(b.statSync().modified);
        }
        return 0;
      });

      int currentSize = 0;
      const targetSize = maxCacheSizeMb * 1024 * 1024 * 0.5;

      for (var entity in files) {
        if (entity is File) {
          currentSize += await entity.length();
        }
      }

      for (var entity in files) {
        if (entity is File && currentSize > targetSize) {
          final fileSize = await entity.length();
          await entity.delete();
          currentSize -= fileSize;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('media_cache_size_bytes', currentSize);

    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }
}
