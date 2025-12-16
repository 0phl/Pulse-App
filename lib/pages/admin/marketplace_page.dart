import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
// auth_service import removed as it's no longer needed
import '../../models/market_item.dart';
import 'package:intl/intl.dart';
import '../../widgets/image_viewer_page.dart';
import '../../widgets/multi_image_viewer_page.dart';
import '../../widgets/admin_scaffold.dart';

class AdminMarketplacePage extends StatefulWidget {
  final int initialTabIndex;

  const AdminMarketplacePage({super.key, this.initialTabIndex = 0});

  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  String _communityName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _marketItems = [];
  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  String _selectedTimeRange = 'Week';
  Map<String, dynamic> _marketStats = {
    'totalItems': 0,
    'activeItems': 0,
    'soldItems': 0,
    'pendingItems': 0,
    'totalValue': 0.0,
    'averagePrice': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex < 4 ? widget.initialTabIndex : 0);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadCommunity(),
        _loadMarketItems(),
        _loadPendingItems(),
        _loadMarketStats(),
        _loadRecentTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null && mounted) {
        setState(() => _communityName = community.name);
      }
    } catch (e) {
      print('Error loading community: $e');
    }
  }

  Future<void> _loadMarketItems() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community == null) return;

      final snapshot = await _adminService.getMarketItems(community.id);
      if (mounted) {
        setState(() {
          _marketItems = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            List<String> imageUrls = [];
            if (data['imageUrls'] != null) {
              // New format with multiple images
              imageUrls = List<String>.from(data['imageUrls']);
            } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
              // Old format with single image
              imageUrls = [data['imageUrl']];
            }

            return {
              ...data,
              'id': doc.id,
              'isSold': data['isSold'] ?? false,
              'title': data['title'] ?? 'Untitled',
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
              'imageUrl': data['imageUrl'] ?? '',
              'imageUrls': imageUrls,
              'description': data['description'] ?? '',
              'sellerName': data['sellerName'] ?? 'Unknown Seller',
              'sellerId': data['sellerId'] ?? '',
              'status': data['status'] ?? 'pending',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
              'rejectionReason': data['rejectionReason'],
            };
          }).toList();

          // Filter out pending items from the listings tab
          _marketItems = _marketItems.where((item) => item['status'] != 'pending').toList();
        });
      }
    } catch (e) {
      print('Error loading market items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading market items: $e')),
        );
      }
    }
  }

  Future<void> _loadPendingItems() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community == null) return;

      final snapshot = await _adminService.getPendingMarketItems(community.id);
      if (mounted) {
        setState(() {
          _pendingItems = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            List<String> imageUrls = [];
            if (data['imageUrls'] != null) {
              // New format with multiple images
              imageUrls = List<String>.from(data['imageUrls']);
            } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
              // Old format with single image
              imageUrls = [data['imageUrl']];
            }

            return {
              ...data,
              'id': doc.id,
              'isSold': data['isSold'] ?? false,
              'title': data['title'] ?? 'Untitled',
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
              'imageUrl': data['imageUrl'] ?? '',
              'imageUrls': imageUrls,
              'description': data['description'] ?? '',
              'sellerName': data['sellerName'] ?? 'Unknown Seller',
              'sellerId': data['sellerId'] ?? '',
              'status': data['status'] ?? 'pending',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading pending items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pending items: $e')),
        );
      }
    }
  }

  Future<void> _loadMarketStats() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community == null) return;

      final stats = await _adminService.getMarketStats(community.id);

      stats['pendingItems'] = _pendingItems.length;

      if (mounted) {
        setState(() {
          _marketStats = stats;
        });
      }
    } catch (e) {
      print('Error loading market stats: $e');
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community == null) return;

      final transactions =
          await _adminService.getRecentTransactions(community.id);
      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  // Method to handle image taps and open the image viewer
  void _handleImageTap(dynamic imageData) {
    if (imageData is List<String>) {
      if (imageData.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiImageViewerPage(
            imageUrls: imageData,
            initialIndex: 0,
          ),
        ),
      );
    } else if (imageData is String) {
      if (imageData.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(imageUrl: imageData),
        ),
      );
    }
  }

  // _signOut method removed as it's no longer needed

  Future<void> _showItemOptions(Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _viewItemDetails(item);
              },
            ),
            if (item['status'] == 'pending')
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Approve Item'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmApproveItem(item['id']);
                },
              ),
            if (item['status'] == 'pending')
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Reject Item'),
                onTap: () {
                  Navigator.pop(context);
                  _showRejectDialog(item['id']);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove Item'),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveItem(item['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewItemDetails(Map<String, dynamic> item) async {
    try {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item['imageUrls'] != null && (item['imageUrls'] as List).isNotEmpty) {
                            _handleImageTap(item['imageUrls']);
                          } else if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
                            _handleImageTap(item['imageUrl']);
                          }
                        },
                        child: Hero(
                          tag: 'item_${item['id']}',
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildItemImage(item),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? 'Untitled',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (item['isSold'] ?? false)
                                        ? Colors.red[50]
                                        : Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (item['isSold'] ?? false)
                                        ? 'Sold'
                                        : 'Active',
                                    style: TextStyle(
                                      color: (item['isSold'] ?? false)
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₱${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00C49A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['description'] ?? 'No description',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Seller Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['sellerName'] ?? 'Unknown Seller',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (item['createdAt'] != null)
                              Text(
                                'Posted on ${DateFormat('MMMM d, y').format((item['createdAt'] as Timestamp).toDate())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing item details: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemoveItem(String itemId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeItem(itemId);
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      await _adminService.removeMarketItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
        _loadMarketItems();
        _loadPendingItems();
        _loadMarketStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  Future<void> _confirmApproveItem(String itemId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Item'),
        content: const Text('Are you sure you want to approve this item? It will be visible to all users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _approveItem(itemId);
    }
  }

  Future<void> _approveItem(String itemId) async {
    try {
      await _adminService.approveMarketItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item approved successfully')),
        );
        _loadMarketItems();
        _loadPendingItems();
        _loadMarketStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving item: $e')),
        );
      }
    }
  }

  Future<void> _rejectItem(String itemId, String rejectionReason) async {
    try {
      await _adminService.rejectMarketItem(itemId, rejectionReason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item rejected successfully')),
        );
        _loadMarketItems();
        _loadPendingItems();
        _loadMarketStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting item: $e')),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String itemId) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
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
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      await _rejectItem(itemId, reasonController.text.trim());
    }
  }

  // Removed _warnSeller method as it's no longer needed

  // _bulkAction method removed as it's no longer needed

  Widget _buildSalesChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedTimeRange,
                  items: ['Today', 'Week', 'Month', 'Year']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTimeRange = value);
                      _loadMarketItems();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _buildSimpleBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBarChart() {
    final List<_SalesData> data = _marketItems
        .where((item) => item['isSold'] == true)
        .map((item) {
          final date = item['createdAt'] as DateTime?;
          return date != null
              ? _SalesData(
                  DateFormat('E').format(date),
                  item['price'].toDouble(),
                )
              : null;
        })
        .whereType<_SalesData>()
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth - 40) / (data.isEmpty ? 1 : data.length);
        final maxValue = data.isEmpty
            ? 0.0
            : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

        return Stack(
          children: [
            // Y-axis labels
            Positioned(
              left: 0,
              top: 0,
              bottom: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₱${maxValue.toStringAsFixed(0)}'),
                  Text('₱${(maxValue / 2).toStringAsFixed(0)}'),
                  const Text('₱0'),
                ],
              ),
            ),
            // Bars
            Positioned(
              left: 40,
              right: 0,
              top: 0,
              bottom: 20,
              child: data.isEmpty
                  ? const Center(child: Text('No sales data'))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.map((sale) {
                        final height = maxValue > 0
                            ? (sale.value / maxValue) *
                                (constraints.maxHeight - 40)
                            : 0.0;
                        return SizedBox(
                          width: barWidth - 8,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sale.day,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    if (_recentTransactions.isEmpty) {
      return const Center(
        child: Text('No recent transactions'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _recentTransactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: GestureDetector(
              onTap: () {
                if (transaction['imageUrls'] != null && (transaction['imageUrls'] as List).isNotEmpty) {
                  _handleImageTap(transaction['imageUrls']);
                } else if (transaction['imageUrl'] != null && transaction['imageUrl'].toString().isNotEmpty) {
                  _handleImageTap(transaction['imageUrl']);
                }
              },
              child: Hero(
                tag: 'transaction_${transaction['id']}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _buildTransactionImage(transaction),
                  ),
                ),
              ),
            ),
            title: Text(transaction['title']),
            subtitle: Text(
              DateFormat('MMM d, y').format(
                (transaction['date'] as Timestamp).toDate(),
              ),
            ),
            trailing: Text(
              '₱${transaction['amount'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Market Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAnalyticItem(
                        'Average Price',
                        '₱${_marketStats['averagePrice'].toStringAsFixed(2)}',
                        Icons.trending_up,
                      ),
                      _buildAnalyticItem(
                        'Total Value',
                        '₱${_marketStats['totalValue'].toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),
                      _buildAnalyticItem(
                        'Success Rate',
                        '${(_marketStats['soldItems'] / (_marketStats['totalItems'] == 0 ? 1 : _marketStats['totalItems']) * 100).toStringAsFixed(1)}%',
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  // TODO: Add category distribution chart
                  Center(
                    child:
                        Text('Category distribution chart will be added here'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Settings tab removed as requested

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Marketplace - $_communityName',
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
        title: Text(
          'Marketplace - $_communityName',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.store), text: 'Listings'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildListingsTab(),
            _buildPendingTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Total Items',
          _marketStats['totalItems'].toString(),
          Icons.inventory,
          const Color(0xFF1976D2),
        ),
        _buildStatCard(
          'Active Listings',
          _marketStats['activeItems'].toString(),
          Icons.store,
          const Color(0xFF00C49A),
        ),
        _buildStatCard(
          'Items Sold',
          _marketStats['soldItems'].toString(),
          Icons.shopping_cart,
          const Color(0xFFFF9800),
        ),
        _buildStatCard(
          'Pending Approval',
          _marketStats['pendingItems'].toString(),
          Icons.pending_actions,
          const Color(0xFFFFA000),
        ),
        _buildStatCard(
          'Total Value',
          '₱${_marketStats['totalValue'].toStringAsFixed(2)}',
          Icons.attach_money,
          const Color(0xFF9C27B0),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF00C49A)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    // TODO: Implement search functionality
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list, color: Color(0xFF00C49A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    setState(() {
                      _selectedTimeRange = value;
                    });
                    _loadMarketItems();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'Week',
                      child: Text('Last Week'),
                    ),
                    const PopupMenuItem(
                      value: 'Month',
                      child: Text('Last Month'),
                    ),
                    const PopupMenuItem(
                      value: 'Year',
                      child: Text('Last Year'),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C49A)))
              : _marketItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_mall_directory_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No items found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: _marketItems.length,
                      itemBuilder: (context, index) {
                        final item = _marketItems[index];
                        final bool isSold = item['isSold'] ?? false;
                        final String title = item['title'] ?? 'Untitled';
                        final double price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final String imageUrl = item['imageUrl'] ?? '';
                        final String status = item['status'] ?? 'pending';

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _showItemOptions(item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (item['imageUrls'] != null && (item['imageUrls'] as List).isNotEmpty) {
                                            _handleImageTap(item['imageUrls']);
                                          } else if (imageUrl.isNotEmpty) {
                                            _handleImageTap(imageUrl);
                                          }
                                        },
                                        child: Hero(
                                          tag: 'listing_${item['id']}',
                                          child: _buildItemImage(item),
                                        ),
                                      ),
                                      if (isSold)
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
                                      // Removed PENDING label as it has its own tab
                                      if (!isSold && status == 'rejected')
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'REJECTED',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₱${price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF00C49A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status, isSold),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(status, isSold),
                                          style: TextStyle(
                                            color: _getStatusTextColor(status, isSold),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status, bool isSold) {
    if (isSold) return Colors.red[50]!;
    switch (status) {
      case 'approved': return Colors.green[50]!;
      case 'pending': return Colors.orange[50]!;
      case 'rejected': return Colors.red[50]!;
      default: return Colors.grey[50]!;
    }
  }

  Color _getStatusTextColor(String status, bool isSold) {
    if (isSold) return Colors.red;
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status, bool isSold) {
    if (isSold) return 'Sold';
    switch (status) {
      case 'approved': return 'Active';
      case 'pending': return 'Pending';
      case 'rejected': return 'Rejected';
      default: return 'Unknown';
    }
  }

  // Helper method to build item image
  Widget _buildItemImage(Map<String, dynamic> item) {
    if (item['imageUrls'] != null && (item['imageUrls'] as List).isNotEmpty) {
      final imageUrl = (item['imageUrls'] as List<String>)[0];
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
      return Image.network(
        item['imageUrl'],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else {
      // No image available
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported),
      );
    }
  }

  // Helper method to build transaction image
  Widget _buildTransactionImage(Map<String, dynamic> transaction) {
    if (transaction['imageUrls'] != null && (transaction['imageUrls'] as List).isNotEmpty) {
      final imageUrl = (transaction['imageUrls'] as List<String>)[0];
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else if (transaction['imageUrl'] != null && transaction['imageUrl'].toString().isNotEmpty) {
      return Image.network(
        transaction['imageUrl'],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else {
      // No image available
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported),
      );
    }
  }

  Widget _buildPendingTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Items Pending Approval',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00C49A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '${_pendingItems.length} pending',
                  style: const TextStyle(
                    color: Color(0xFF00C49A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C49A)))
              : _pendingItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No pending items',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All items have been reviewed',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingItems.length,
                      itemBuilder: (context, index) {
                        final item = _pendingItems[index];
                        final String title = item['title'] ?? 'Untitled';
                        final double price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;
                        final String imageUrl = item['imageUrl'] ?? '';
                        final String sellerName = item['sellerName'] ?? 'Unknown Seller';
                        final Timestamp createdAt = item['createdAt'] as Timestamp? ?? Timestamp.now();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _viewItemDetails(item),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (item['imageUrls'] != null && (item['imageUrls'] as List).isNotEmpty) {
                                        _handleImageTap(item['imageUrls']);
                                      } else if (imageUrl.isNotEmpty) {
                                        _handleImageTap(imageUrl);
                                      }
                                    },
                                    child: Hero(
                                      tag: 'pending_${item['id']}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 80,
                                          height: 80,
                                          child: _buildItemImage(item),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₱${price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF00C49A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Seller: $sellerName',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Posted: ${DateFormat('MMM d, y').format(createdAt.toDate())}',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _confirmApproveItem(item['id']),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _showRejectDialog(item['id']),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SalesData {
  final String day;
  final double value;

  _SalesData(this.day, this.value);
}
