import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_item.dart';
import '../models/seller_rating.dart';
import '../services/market_service.dart';

class SellerProfilePage extends StatefulWidget {
  final String sellerId;
  final String? sellerName;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
    this.sellerName,
  });

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with SingleTickerProviderStateMixin {
  final MarketService _marketService = MarketService();
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _sellerProfile = {};
  List<MarketItem> _sellerItems = [];
  List<SellerRating> _sellerRatings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSellerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    try {
      final profile = await _marketService.getSellerProfile(widget.sellerId);

      if (mounted) {
        setState(() {
          _sellerProfile = profile;
          _isLoading = false;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final isCurrentUser = currentUser != null && currentUser.uid == widget.sellerId;

      // For other sellers' profiles, this will only show active (not sold) items
      _marketService.getSellerItemsStream(widget.sellerId, isCurrentUser: isCurrentUser).listen((items) {
        if (mounted) {
          setState(() {
            _sellerItems = items;
          });
        }
      });

      _marketService.getSellerRatingsStream(widget.sellerId).listen((ratings) {
        if (mounted) {
          setState(() {
            _sellerRatings = ratings;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading seller data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Rating functionality removed - ratings only allowed through chat

  Future<void> _showReportSellerDialog() async {
    final TextEditingController reasonController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Seller'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for reporting this seller:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (result == true) {
      // In a real app, you would send this report to your backend
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller reported successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sellerName ?? 'Seller Profile'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _showReportSellerDialog,
            tooltip: 'Report Seller',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSellerHeader(),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF00C49A),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF00C49A),
                  tabs: [
                    Tab(text: FirebaseAuth.instance.currentUser?.uid == widget.sellerId ? 'Items' : 'Active Items'),
                    const Tab(text: 'Reviews'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItemsTab(),
                      _buildReviewsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSellerHeader() {
    final String name = _sellerProfile['name'] ?? 'Unknown Seller';
    final double rating = _sellerProfile['averageRating'] ?? 0.0;
    final int ratingsCount = _sellerProfile['ratingsCount'] ?? 0;
    final DateTime? joinedDate = _sellerProfile['joinedDate'];
    final String profileImage = _sellerProfile['profileImage'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF00C49A).withOpacity(0.05),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage: profileImage.isNotEmpty
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($ratingsCount ${ratingsCount == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (joinedDate != null)
                      Text(
                        'Member since ${DateFormat('MMMM yyyy').format(joinedDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              // Rate button removed - ratings only allowed through chat
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    if (_sellerItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              FirebaseAuth.instance.currentUser?.uid == widget.sellerId
                ? 'No items available'
                : 'No active items available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              FirebaseAuth.instance.currentUser?.uid == widget.sellerId
                ? 'You have no items for sale'
                : 'This seller has no active items for sale',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: _sellerItems.length,
      itemBuilder: (context, index) {
        final item = _sellerItems[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.imageUrls.isNotEmpty ? item.imageUrls[0] : '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                    if (item.isSold)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Text(
                            'SOLD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (!item.isSold && item.status == 'pending')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u20b1${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF00C49A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_sellerRatings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this seller',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            // Rate button removed - ratings only allowed through chat
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sellerRatings.length,
      itemBuilder: (context, index) {
        final rating = _sellerRatings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: rating.buyerAvatar != null
                          ? NetworkImage(rating.buyerAvatar!)
                          : null,
                      child: rating.buyerAvatar == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rating.buyerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y').format(rating.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
                if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    rating.comment!,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
