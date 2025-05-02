import 'package:flutter/material.dart';
import 'multi_image_viewer_page.dart';
import '../services/cloudinary_service.dart';

class ImageGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double maxHeight;
  final double minHeight;
  final bool maintainAspectRatio;
  final bool isInTabbedView;

  const ImageGalleryViewer({
    super.key,
    required this.imageUrls,
    this.height = 250,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.contain,
    this.maxHeight = 500,
    this.minHeight = 200,
    this.maintainAspectRatio = true,
    this.isInTabbedView = false,
  });

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  final PageController _pageController = PageController();
  final Map<String, Size> _imageDimensions = {};
  final Map<String, bool> _imageLoaded = {};

  @override
  void initState() {
    super.initState();
    // Preload image dimensions
    for (var url in widget.imageUrls) {
      _preloadImageDimensions(url);
    }
  }

  void _preloadImageDimensions(String imageUrl) {
    // Get optimized URL for preloading
    final cloudinaryService = CloudinaryService();
    final optimizedUrl = cloudinaryService.getOptimizedImageUrl(imageUrl);

    final image = Image.network(optimizedUrl);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageDimensions[imageUrl] = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            _imageLoaded[imageUrl] = true;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox();
    }

    // Calculate appropriate height based on available images
    double calculatedHeight = widget.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = widget.width ?? screenWidth - 24; // Reduced padding for more space

    // If we have image dimensions, use them to calculate a better height for single image
    if (widget.maintainAspectRatio && widget.imageUrls.length == 1) {
      String firstImageUrl = widget.imageUrls[0];
      final isLoaded = _imageLoaded[firstImageUrl] ?? false;
      final dimensions = _imageDimensions[firstImageUrl];

      if (isLoaded && dimensions != null) {
        final aspectRatio = dimensions.width / dimensions.height;
        final bool isSmallImage = dimensions.width < 500 && dimensions.height < 500;
        final bool isVerySmallImage = dimensions.width < 300 && dimensions.height < 300;
        final bool isTinyImage = dimensions.width < 200 && dimensions.height < 200;

        // Special handling for mixed media posts (when images are shown alongside videos)
        final bool isInMixedMediaPost = widget.width != null && widget.width == double.infinity;

        // Determine if this is a portrait image
        final bool isPortrait = aspectRatio < 1.0;

        // For tabbed view (community notices), handle small images with minimal whitespace
        if (widget.isInTabbedView) {
          if (isTinyImage || isVerySmallImage) {
            // For very small images, use actual dimensions with slight padding
            final double scaleFactor = isPortrait ? 1.2 : 1.0;
            calculatedHeight = (dimensions.height * scaleFactor).clamp(150.0, 300.0);
          } else if (isSmallImage) {
            // For small images, use moderate height but maintain aspect ratio
            calculatedHeight = isPortrait
                ? availableWidth * 0.9  // Slightly taller for portrait
                : availableWidth * 0.6; // More compact for landscape
          } else if (isPortrait) {
            calculatedHeight = availableWidth * 0.9; // Keep portrait images contained
          } else {
            calculatedHeight = availableWidth * 0.6; // More compact for normal landscape
          }
        } else if (isPortrait) {
          // For portrait images, use a taller height
          calculatedHeight = availableWidth * 1.5; // Taller for portrait
        } else if (isTinyImage && isInMixedMediaPost) {
          // For tiny images in mixed media posts, use a fixed height to avoid too much white space
          calculatedHeight = availableWidth * 0.6;
        } else if (isVerySmallImage) {
          // For very small images, don't make them too tall
          calculatedHeight = availableWidth * 0.7; // Shorter height for small images
        } else if (isSmallImage) {
          // For small images, use a moderate height
          calculatedHeight = availableWidth * 0.8;
        } else {
          // For landscape images, calculate based on aspect ratio
          calculatedHeight = availableWidth / aspectRatio;
        }

        // Apply min/max constraints with higher max for portrait
        calculatedHeight = calculatedHeight.clamp(
          widget.minHeight,
          isPortrait ? widget.maxHeight * 1.2 : widget.maxHeight
        );
      }
    }

    // For multiple images, use a fixed height that's appropriate for a grid
    if (widget.imageUrls.length > 1) {
      // Use a height that works well for grids
      if (widget.imageUrls.length == 2) {
        calculatedHeight = 220.0; // Shorter for 2 images side by side
      } else if (widget.imageUrls.length == 3) {
        calculatedHeight = 240.0; // Good height for side-by-side layout with stacked images
      } else {
        calculatedHeight = 320.0; // Tallest for 4+ images in a 2x2 grid
      }
    }

    // Ensure we don't exceed the maximum height
    calculatedHeight = calculatedHeight.clamp(widget.minHeight, widget.maxHeight);

    // Single image view
    if (widget.imageUrls.length == 1) {
      final imageUrl = widget.imageUrls[0];

      // Determine appropriate fit based on image dimensions
      BoxFit imageFit = widget.fit;
      final dimensions = _imageDimensions[imageUrl];
      if (dimensions != null) {
        final aspectRatio = dimensions.width / dimensions.height;
        final isPortrait = aspectRatio < 1.0;
        final isSmallImage = dimensions.width < 500 && dimensions.height < 500;
        final isVerySmallImage = dimensions.width < 300 && dimensions.height < 300;
        final isTinyImage = dimensions.width < 200 && dimensions.height < 200;

        // Special handling for different image types
        final bool isInMixedMediaPost = widget.width != null && widget.width == double.infinity;

        // Always use cover for images in tabbed view to eliminate white space
        if (widget.isInTabbedView) {
          // Always use cover for all images in tabbed view to fill container completely
          imageFit = BoxFit.cover;
        } else if (isPortrait || isSmallImage || isVerySmallImage || isTinyImage) {
          // Use cover for portrait and small images to reduce white space
          imageFit = BoxFit.cover;
        }
      }

      return SizedBox(
        width: widget.width ?? double.infinity,
        height: calculatedHeight,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MultiImageViewerPage(
                  imageUrls: widget.imageUrls,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Hero(
                tag: imageUrl,
                child: Container(
                  color: const Color(0xFF00C49A).withOpacity(0.05), // Light teal background to match app theme
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.network(
                    // Use optimized URL for better performance and bandwidth savings
                    CloudinaryService().getOptimizedImageUrl(imageUrl, isListView: false),
                    fit: imageFit,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: widget.borderRadius,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 48),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C49A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Image not available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF00C49A).withOpacity(0.05),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF00C49A),
                              strokeWidth: 2,
                            ),
                            if (loadingProgress.expectedTotalBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  '${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images - use a grid layout
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: calculatedHeight,
      child: _buildImageGrid(),
    );
  }

  // Build a grid of images
  Widget _buildImageGrid() {
    final int imageCount = widget.imageUrls.length;

    // Determine grid layout based on number of images
    if (imageCount == 2) {
      // Two images side by side
      return Row(
        children: [
          Expanded(child: _buildGridItem(0)),
          const SizedBox(width: 4),
          Expanded(child: _buildGridItem(1)),
        ],
      );
    } else if (imageCount == 3) {
      // One large image on left, two stacked on right
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildGridItem(0),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildGridItem(1)),
                const SizedBox(height: 4),
                Expanded(child: _buildGridItem(2)),
              ],
            ),
          ),
        ],
      );
    } else if (imageCount == 4) {
      // 2x2 grid
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGridItem(0)),
                const SizedBox(width: 4),
                Expanded(child: _buildGridItem(1)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGridItem(2)),
                const SizedBox(width: 4),
                Expanded(child: _buildGridItem(3)),
              ],
            ),
          ),
        ],
      );
    } else {
      // More than 4 images - show only first 4 with a "+X" overlay on the last one
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGridItem(0)),
                const SizedBox(width: 4),
                Expanded(child: _buildGridItem(1)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildGridItem(2)),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Open the gallery viewer at the 4th image when tapping on the "+X more" overlay
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MultiImageViewerPage(
                            imageUrls: widget.imageUrls,
                            initialIndex: 3, // Start at the 4th image (index 3)
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildGridItem(3, showHero: false, disableGesture: true),
                        if (imageCount > 4)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.2),
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: widget.borderRadius,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '+${imageCount - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'more',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // Build a single grid item
  Widget _buildGridItem(int index, {bool showHero = true, bool disableGesture = false}) {
    final imageUrl = widget.imageUrls[index];

    Widget gridItemContent = Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        // Removed white border to eliminate white space
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 0.5,
            offset: const Offset(0, 1),
          ),
        ],
        // Add a background color to match the app theme
        color: const Color(0xFF00C49A).withOpacity(0.05),
      ),
      // Ensure the container fills its parent completely
      width: double.infinity,
      height: double.infinity,
      child: ClipRRect(
        borderRadius: widget.borderRadius, // Use exact same border radius as container
        child: showHero
            ? Hero(
                tag: '${imageUrl}_$index',
                child: _buildImageWithFit(imageUrl),
              )
            : _buildImageWithFit(imageUrl),
      ),
    );

    // If gesture is disabled, return the content without GestureDetector
    if (disableGesture) {
      return gridItemContent;
    }

    // Otherwise wrap with GestureDetector
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultiImageViewerPage(
              imageUrls: widget.imageUrls,
              initialIndex: index,
            ),
          ),
        );
      },
      child: gridItemContent,
    );
  }

  // Build image with appropriate fit
  Widget _buildImageWithFit(String imageUrl) {
    // Check if we have dimensions for this image
    final dimensions = _imageDimensions[imageUrl];
    BoxFit imageFit = BoxFit.cover; // Default to cover

    // Always use cover or fill to eliminate white space
    if (dimensions != null) {
      final bool isSmallImage = dimensions.width < 500 && dimensions.height < 500;
      final bool isVerySmallImage = dimensions.width < 300 && dimensions.height < 300;
      final bool isTinyImage = dimensions.width < 200 && dimensions.height < 200;

      // For tabbed view (community notices), always use cover to fill the container
      if (widget.isInTabbedView) {
        // Use cover for all images in tabbed view to eliminate white space
        imageFit = BoxFit.cover;
      } else if (isTinyImage || isVerySmallImage) {
        // For very small images, use fill to avoid white space
        imageFit = BoxFit.fill;
      } else if (isSmallImage) {
        // For small images, use cover
        imageFit = BoxFit.cover;
      }
    }

    // Container for image display

    return Container(
      // Ensure the image container fills all available space
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF00C49A).withOpacity(0.05), // Light teal background to match app theme
      child: Image.network(
        // Use optimized URL for better performance and bandwidth savings
        CloudinaryService().getOptimizedImageUrl(imageUrl, isListView: true),
        fit: imageFit, // Use the determined fit based on image size
        width: double.infinity, // Force image to take full width
        height: double.infinity, // Force image to take full height
        alignment: Alignment.center, // Center the image
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.05),
              borderRadius: widget.borderRadius, // Use exact same border radius as container
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C49A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Image not available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.05),
              borderRadius: widget.borderRadius, // Use exact same border radius as container
            ),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF00C49A),
                      strokeWidth: 2,
                    ),
                  ),
                  if (loadingProgress.expectedTotalBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
