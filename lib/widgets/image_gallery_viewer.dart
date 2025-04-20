import 'package:flutter/material.dart';
import 'multi_image_viewer_page.dart';

class ImageGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const ImageGalleryViewer({
    super.key,
    required this.imageUrls,
    this.height = 200,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

    // Calculate image height by reserving space for dots if multiple images
    final double paginationHeight = widget.imageUrls.length > 1 ? 16 : 0;
    final double imageHeight = widget.height - paginationHeight;

    return SizedBox(
      height: widget.height,
      width: widget.width ?? double.infinity,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
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
                  child: Hero(
                    tag: imageUrl,
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child:
                                  Icon(Icons.error_outline, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.imageUrls.length > 1)
            SizedBox(
              height: paginationHeight,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.imageUrls.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
