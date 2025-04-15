import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/market_item.dart';
import '../services/market_service.dart';
import '../widgets/shimmer_loading.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({Key? key}) : super(key: key);

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> with SingleTickerProviderStateMixin {
  final MarketService _marketService = MarketService();
  late TabController _tabController;
  bool _isLoading = true;

  // Dashboard stats
  Map<String, dynamic> _dashboardStats = {};

  // Items lists for the overview tab
  List<MarketItem> _pendingItems = [];
  List<MarketItem> _approvedItems = [];
  List<MarketItem> _rejectedItems = [];
  List<MarketItem> _soldItems = [];

  // Streams for the tab views
  Stream<List<MarketItem>>? _pendingItemsStream;
  Stream<List<MarketItem>>? _rejectedItemsStream;
  Stream<List<MarketItem>>? _soldItemsStream;

  // Seller ratings
  double _averageRating = 0.0;
  int _totalRatings = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeStreams();
    _loadSellerData();
  }

  void _initializeStreams() {
    try {
      _pendingItemsStream = _marketService.getSellerItemsByStatusStream('pending');
      // We don't need the approved items stream for now
      _rejectedItemsStream = _marketService.getSellerItemsByStatusStream('rejected');
      _soldItemsStream = _marketService.getSellerSoldItemsStream();
    } catch (e) {
      // Log error
      debugPrint('Error initializing streams: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load seller dashboard stats
      final stats = await _marketService.getSellerDashboardStats();

      // Load items by status
      final pendingItems = await _marketService.getSellerItemsByStatus('pending');
      final approvedItems = await _marketService.getSellerItemsByStatus('approved');
      final rejectedItems = await _marketService.getSellerItemsByStatus('rejected');
      final soldItems = await _marketService.getSellerSoldItems();

      // Load seller rating info
      final ratingInfo = await _marketService.getSellerRatingInfo();

      if (mounted) {
        setState(() {
          _dashboardStats = stats;
          _pendingItems = pendingItems;
          _approvedItems = approvedItems;
          _rejectedItems = rejectedItems;
          _soldItems = soldItems;
          _averageRating = ratingInfo['averageRating'] ?? 0.0;
          _totalRatings = ratingInfo['totalRatings'] ?? 0;
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSellerData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Pending'),
            Tab(text: 'Rejected'),
            Tab(text: 'Sold'),
          ],
        ),
      ),
      body: _isLoading
          ? const ShimmerLoading()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildItemsStreamTab(_pendingItemsStream, 'No pending items'),
                _buildItemsStreamTab(_rejectedItemsStream, 'No rejected items'),
                _buildItemsStreamTab(_soldItemsStream, 'No sold items'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add new item page
          Navigator.pushNamed(context, '/add_item').then((_) => _loadSellerData());
        },
        backgroundColor: const Color(0xFF00C49A),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return RefreshIndicator(
      onRefresh: _loadSellerData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Rating Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Seller Rating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 36,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($_totalRatings ${_totalRatings == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sales Summary Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      'Total Revenue',
                      currencyFormat.format(_dashboardStats['totalRevenue'] ?? 0),
                      Icons.attach_money,
                      Colors.green,
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Items Sold',
                      '${_dashboardStats['itemsSold'] ?? 0}',
                      Icons.shopping_bag,
                      Colors.blue,
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Average Item Price',
                      currencyFormat.format(_dashboardStats['averagePrice'] ?? 0),
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Items Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      'Pending Approval',
                      '${_pendingItems.length}',
                      Icons.pending,
                      Colors.orange,
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Active Listings',
                      '${_approvedItems.length}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Rejected Items',
                      '${_rejectedItems.length}',
                      Icons.cancel,
                      Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recent Activity Card
            if (_dashboardStats['recentActivity'] != null &&
                (_dashboardStats['recentActivity'] as List).isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildRecentActivityList(),
                    ],
                  ),
                ),
              ),

            // Recent Sold Items Card
            if (_soldItems.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Sales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _soldItems.length > 3 ? 3 : _soldItems.length,
                        itemBuilder: (context, index) {
                          final item = _soldItems[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: item.imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              currencyFormat.format(item.price),
                              style: const TextStyle(color: Colors.green),
                            ),
                            trailing: Text(
                              DateFormat('MMM d, yyyy').format(_getDateTime(item.createdAt, item: item)),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          );
                        },
                      ),
                      if (_soldItems.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: () {
                              _tabController.animateTo(3); // Navigate to Sold tab
                            },
                            child: const Text('View all sales'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentActivityList() {
    final activities = _dashboardStats['recentActivity'] as List;
    return activities.map((activity) {
      final DateTime timestamp = (activity['timestamp'] as Timestamp).toDate();
      final String formattedDate = DateFormat('MMM d, y').format(timestamp);

      IconData activityIcon;
      Color activityColor;

      switch (activity['type']) {
        case 'item_approved':
          activityIcon = Icons.check_circle;
          activityColor = Colors.green;
          break;
        case 'item_rejected':
          activityIcon = Icons.cancel;
          activityColor = Colors.red;
          break;
        case 'item_sold':
          activityIcon = Icons.shopping_bag;
          activityColor = Colors.blue;
          break;
        case 'new_rating':
          activityIcon = Icons.star;
          activityColor = Colors.amber;
          break;
        default:
          activityIcon = Icons.notifications;
          activityColor = Colors.grey;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              activityIcon,
              color: activityColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['message'] ?? 'Activity',
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helper method to convert various date formats to DateTime
  // For sold items, prefer using soldAt if available
  DateTime _getDateTime(dynamic dateValue, {MarketItem? item}) {
    // If this is a sold item and it has a soldAt timestamp, use that
    if (item != null && item.isSold && item.soldAt != null) {
      return item.soldAt!;
    }

    if (dateValue == null) {
      return DateTime.now();
    } else if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is DateTime) {
      return dateValue;
    } else {
      return DateTime.now();
    }
  }

  // This method is used for the overview tab only

  Widget _buildItemsStreamTab(Stream<List<MarketItem>>? itemsStream, String emptyMessage) {
    if (itemsStream == null) {
      return const Center(child: Text('Error loading data'));
    }

    return StreamBuilder<List<MarketItem>>(
      stream: itemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadSellerData,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item);
            },
          ),
        );
      },
    );
  }

  Widget _buildItemCard(MarketItem item) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    // Determine status badge color
    Color statusColor;
    IconData statusIcon;

    switch (item.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image and status badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (item.isSold)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: const Center(
                      child: Text(
                        'SOLD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Item details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(item.price),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Show rejection reason if item is rejected
                if (item.status == 'rejected' && item.rejectionReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.rejectionReason!,
                            style: TextStyle(
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Item actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (item.status == 'rejected')
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Resubmit'),
                        onPressed: () => _resubmitItem(item),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    if (item.status != 'approved' || !item.isSold)
                      TextButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove'),
                        onPressed: () => _confirmRemoveItem(item),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resubmitItem(MarketItem item) async {
    try {
      // Create a new item with the same details but reset the status
      final updatedItem = MarketItem(
        id: item.id,
        title: item.title,
        price: item.price,
        description: item.description,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
        imageUrl: item.imageUrl,
        communityId: item.communityId,
        status: 'pending', // Reset to pending
        rejectionReason: null, // Clear rejection reason
      );

      await _marketService.updateMarketItem(updatedItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item resubmitted for approval')),
        );
        _loadSellerData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resubmitting item: $e')),
        );
      }
    }
  }



  Future<void> _confirmRemoveItem(MarketItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _marketService.deleteMarketItem(item.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item removed successfully')),
          );
          _loadSellerData(); // Refresh data
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing item: $e')),
          );
        }
      }
    }
  }
}

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShimmerCard(100),
        const SizedBox(height: 16),
        _buildShimmerCard(150),
        const SizedBox(height: 16),
        _buildShimmerCard(120),
        const SizedBox(height: 16),
        _buildShimmerCard(200),
      ],
    );
  }

  Widget _buildShimmerCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
