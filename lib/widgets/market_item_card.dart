import 'package:flutter/material.dart';
import '../models/market_item.dart';
import 'dart:io';
import 'dart:async';
import 'package:transparent_image/transparent_image.dart';
import '../services/market_service.dart';
import 'multi_image_viewer_page.dart';

class MarketItemCard extends StatefulWidget {
  final MarketItem item;
  final VoidCallback onInterested;
  final VoidCallback onImageTap;
  final bool isOwner;
  final bool showEditButton;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSellerTap;
  final int? unreadCount;
  final bool isGridView;

  const MarketItemCard({
    super.key,
    required this.item,
    required this.onInterested,
    required this.onImageTap,
    required this.isOwner,
    this.showEditButton = false,
    this.onEdit,
    this.onDelete,
    this.onSellerTap,
    this.unreadCount,
    this.isGridView = false,
  });

  @override
  State<MarketItemCard> createState() => _MarketItemCardState();
}

class _MarketItemCardState extends State<MarketItemCard> {
  String? sellerProfileImage;
  String? sellerName;
  double sellerRating = 0.0;
  bool isLoading = true;
  final MarketService _marketService = MarketService();
  StreamSubscription? _sellerProfileSubscription;
  final PageController _imagePageController = PageController();
  int _currentImagePage = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToSellerProfile();
  }

  @override
  void dispose() {
    _sellerProfileSubscription?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  void _subscribeToSellerProfile() {
    // First load the data immediately to avoid delay
    _loadSellerData();

    // Then subscribe to real-time updates
    _sellerProfileSubscription = _marketService
        .getSellerProfileStream(widget.item.sellerId)
        .listen((sellerProfile) {
      if (mounted) {
        setState(() {
          sellerProfileImage = sellerProfile['profileImage'];
          sellerRating = sellerProfile['averageRating'] ?? 0.0;
          // This ensures the displayed name is always current
          sellerName = sellerProfile['name'];
          isLoading = false;
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  Future<void> _loadSellerData() async {
    try {
      final sellerProfile = await _marketService.getSellerProfile(widget.item.sellerId);

      if (mounted) {
        setState(() {
          sellerProfileImage = sellerProfile['profileImage'];
          sellerRating = sellerProfile['averageRating'] ?? 0.0;
          sellerName = sellerProfile['name'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper method to build star rating
  List<Widget> _buildRatingStars(double rating) {
    List<Widget> stars = [];

    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;
    int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, size: 14, color: Colors.amber));
    }

    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, size: 14, color: Colors.amber));
    }

    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, size: 14, color: Colors.amber));
    }

    return stars;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: widget.isGridView ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Make column take minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image at the top with status badges
          Stack(
            children: [
              // Image carousel
              GestureDetector(
                onTap: () {
                  // Pass the current image index to the image viewer
                  if (widget.item.imageUrls.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MultiImageViewerPage(
                          imageUrls: widget.item.imageUrls,
                          initialIndex: _currentImagePage,
                        ),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: widget.isGridView ? 1 : 4/3, // Square for grid view
                    child: Stack(
                      children: [
                        // Image PageView
                        PageView.builder(
                          controller: _imagePageController,
                          itemCount: widget.item.imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImagePage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: '${widget.item.id}_image_$index',
                              child: _buildImage(widget.item.imageUrls[index]),
                            );
                          },
                        ),

                        // Page indicator dots (only if more than one image)
                        if (widget.item.imageUrls.length > 1)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.item.imageUrls.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImagePage == index
                                        ? const Color(0xFF00C49A)
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Owner indicator badge for grid view - only show in All Items tab (when showEditButton is false)
              if (widget.isOwner && widget.isGridView && !widget.showEditButton)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C49A).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'YOUR ITEM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Status badges
              if (widget.item.isSold)
                Positioned(
                  top: widget.isGridView ? 6 : 12,
                  left: widget.isGridView ? 6 : 12,
                  child: Container(
                    padding: widget.isGridView
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: widget.isGridView
                        ? const Text(
                            'SOLD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SOLD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              if (!widget.item.isSold && widget.item.status == 'pending')
                Positioned(
                  top: widget.isGridView ? 6 : 12,
                  left: widget.isGridView ? 6 : 12,
                  child: Container(
                    padding: widget.isGridView
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: widget.isGridView
                        ? const Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pending_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              if (!widget.item.isSold && widget.item.status == 'rejected')
                Positioned(
                  top: widget.isGridView ? 6 : 12,
                  left: widget.isGridView ? 6 : 12,
                  child: Container(
                    padding: widget.isGridView
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: widget.isGridView
                        ? const Text(
                            'REJECTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'REJECTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              if (widget.unreadCount != null && widget.unreadCount! > 0)
                Positioned(
                  top: widget.isGridView ? 6 : 12,
                  right: widget.isGridView
                      ? (widget.isOwner && !widget.showEditButton ? 80 : 6)
                      : 12,
                  child: Container(
                    padding: widget.isGridView
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.isGridView ? 10 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Title and price - Adapt layout based on view mode
          Padding(
            padding: widget.isGridView
                ? const EdgeInsets.fromLTRB(8, 4, 8, 8) // Increased bottom padding
                : const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: widget.isGridView
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '₱${widget.item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C49A),
                        ),
                      ),
                      if (widget.item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _showDescriptionDialog(context),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.description,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Only show "More" button if description is longer than 30 characters
                              if (widget.item.description.length > 30)
                                const Text(
                                  'More',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF00C49A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₱${widget.item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C49A),
                        ),
                      ),
                    ],
                  ),
          ),

          // Description - Only show in list view
          if (!widget.isGridView)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _showDescriptionDialog(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Only show 'Tap to read more' if description is longer than ~100 characters
                    // which would likely cause it to be truncated in 2 lines
                    if (widget.item.description.length > 100) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to read more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00C49A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Seller information - Show for all items in All Items tab, hide in My Items tab and in grid view
          if (!widget.showEditButton && !widget.isGridView) // Show in All Items tab (showEditButton is false), hide in My Items tab (showEditButton is true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: widget.onSellerTap,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C49A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C49A).withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile picture circle with mint background
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00C49A).withOpacity(0.15),
                          image: sellerProfileImage != null && sellerProfileImage!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(sellerProfileImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: sellerProfileImage == null || sellerProfileImage!.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 22,
                                color: Color(0xFF00C49A),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Seller name and rating
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  sellerName ?? widget.item.sellerName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF00C49A),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                ..._buildRatingStars(sellerRating),
                                const SizedBox(width: 4),
                                Text(
                                  sellerRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Arrow icon with visual indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C49A).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF00C49A),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (widget.item.status == 'rejected' && widget.item.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.item.rejectionReason!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Edit and Delete buttons for owner
          if (widget.isOwner && widget.showEditButton)
            widget.isGridView
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), // Increased top and bottom padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Edit button with container for larger touch target
                        InkWell(
                          onTap: widget.onEdit,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Increased padding
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C49A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00C49A),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 12, // Adjusted size
                                  color: Color(0xFF00C49A),
                                ),
                                SizedBox(width: 4), // Increased spacing
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00C49A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: widget.onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Increased padding
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 12, // Adjusted size
                                  color: Colors.red,
                                ),
                                SizedBox(width: 4), // Increased spacing
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C49A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text(
                              'Delete Item',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

          // Interested button for non-owners
          if (!widget.isOwner)
            widget.isGridView
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12), // Added top padding and increased bottom padding
                    child: Center(
                      child: InkWell(
                        onTap: widget.item.isSold ? null : widget.onInterested,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Increased padding
                          decoration: BoxDecoration(
                            color: widget.item.isSold ? Colors.grey : const Color(0xFF00C49A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 12, // Increased icon size
                                color: Colors.white,
                              ),
                              SizedBox(width: 4), // Increased spacing
                              Text(
                                'Interested',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11, // Increased font size
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.item.isSold ? null : widget.onInterested,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text(
                          'I\'m Interested',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      // Network image
      return Stack(
        fit: StackFit.expand, // Make stack fill the available space
        children: [
          Container(
            color: Colors.grey[200],
          ),
          FadeInImage.memoryNetwork(
            placeholder: kTransparentImage,
            image: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            imageErrorBuilder: (context, error, stackTrace) =>
                _buildErrorPlaceholder(),
          ),
        ],
      );
    } else {
      // Local file image
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: widget.isGridView ? 24 : 40,
              color: Colors.grey[400],
            ),
            if (!widget.isGridView) // Only show text in list view
              const SizedBox(height: 8),
            if (!widget.isGridView) // Only show text in list view
              Text(
                'Image not available',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDescriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF00C49A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                widget.item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Description content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5, // Max 50% of screen height
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.item.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                ),
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C49A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
