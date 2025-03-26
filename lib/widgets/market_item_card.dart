import 'package:flutter/material.dart';
import '../models/market_item.dart';
import 'dart:io';
import 'package:transparent_image/transparent_image.dart';

class MarketItemCard extends StatelessWidget {
  final MarketItem item;
  final VoidCallback onInterested;
  final VoidCallback onImageTap;
  final bool isOwner;
  final bool showEditButton;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkAsSold;
  final int? unreadCount;

  const MarketItemCard({
    super.key,
    required this.item,
    required this.onInterested,
    required this.onImageTap,
    required this.isOwner,
    this.showEditButton = false,
    this.onEdit,
    this.onDelete,
    this.onMarkAsSold,
    this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onImageTap,
                child: Hero(
                  tag: item.imageUrl,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: _buildImage(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '₱${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C49A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Seller name
                    Text(
                      'Seller: ${item.sellerName}${isOwner ? ' (you)' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isOwner && showEditButton) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C49A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onMarkAsSold,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark as Sold'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.isSold ? Colors.grey : const Color(0xFF00C49A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!isOwner)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: item.isSold ? null : onInterested,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('I\'m Interested'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C49A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.isSold)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
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
          if (unreadCount != null && unreadCount! > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (item.imageUrl.startsWith('http')) {
      // Network image
      return Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[200],
          ),
          FadeInImage.memoryNetwork(
            placeholder: kTransparentImage,
            image: item.imageUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            imageErrorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
          ),
        ],
      );
    } else {
      // Local file image
      return Image.file(
        File(item.imageUrl),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Icon(
        Icons.image_not_supported,
        size: 50,
        color: Colors.grey,
      ),
    );
  }
}
