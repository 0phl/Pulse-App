import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../models/market_item.dart';
import './admin_drawer.dart';
import 'package:intl/intl.dart';

class AdminMarketplacePage extends StatefulWidget {
  const AdminMarketplacePage({super.key});

  @override
  State<AdminMarketplacePage> createState() => _AdminMarketplacePageState();
}

class _AdminMarketplacePageState extends State<AdminMarketplacePage>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  late TabController _tabController;
  String _communityName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _marketItems = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  String _selectedTimeRange = 'Week';
  Map<String, dynamic> _marketStats = {
    'totalItems': 0,
    'activeItems': 0,
    'soldItems': 0,
    'totalValue': 0.0,
    'averagePrice': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
            return {
              ...data,
              'id': doc.id,
              'isSold': data['isSold'] ?? false,
              'title': data['title'] ?? 'Untitled',
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
              'imageUrl': data['imageUrl'] ?? '',
              'description': data['description'] ?? '',
              'sellerName': data['sellerName'] ?? 'Unknown Seller',
              'sellerId': data['sellerId'] ?? '',
              'status': data['status'] ?? 'Unknown',
              'createdAt': data['createdAt'] ?? Timestamp.now(),
            };
          }).toList();
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

  Future<void> _loadMarketStats() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community == null) return;

      final stats = await _adminService.getMarketStats(community.id);
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

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

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
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Remove Item'),
              onTap: () {
                Navigator.pop(context);
                _removeItem(item['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('Warn Seller'),
              onTap: () {
                Navigator.pop(context);
                _warnSeller(item['sellerId']);
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
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            item['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              );
                            },
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

  Future<void> _removeItem(String itemId) async {
    try {
      await _adminService.removeMarketItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed successfully')),
        );
        _loadMarketItems();
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

  Future<void> _warnSeller(String sellerId) async {
    try {
      await _adminService.warnSeller(sellerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller warned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error warning seller: $e')),
        );
      }
    }
  }

  Future<void> _bulkAction() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Remove Inactive Listings'),
              subtitle: const Text('Remove listings older than 30 days'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final community =
                      await _adminService.getCurrentAdminCommunity();
                  if (community == null) return;

                  final snapshot =
                      await _adminService.getMarketItems(community.id);
                  final thirtyDaysAgo =
                      DateTime.now().subtract(const Duration(days: 30));

                  for (var doc in snapshot.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = (data['createdAt'] as Timestamp).toDate();
                    if (!data['isSold'] && createdAt.isBefore(thirtyDaysAgo)) {
                      await _adminService.removeMarketItem(doc.id);
                    }
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Inactive listings removed')),
                    );
                    _loadMarketItems();
                    _loadMarketStats();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Flag Suspicious Listings'),
              subtitle: const Text('Mark listings with unusual prices'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final community =
                      await _adminService.getCurrentAdminCommunity();
                  if (community == null) return;

                  final snapshot =
                      await _adminService.getMarketItems(community.id);
                  final items = snapshot.docs
                      .map((doc) => {
                            ...doc.data() as Map<String, dynamic>,
                            'id': doc.id,
                          })
                      .where((item) => item['isSold'] == false)
                      .toList();

                  double averagePrice = 0;
                  if (items.isNotEmpty) {
                    final total = items
                        .map((item) => (item['price'] as num).toDouble())
                        .reduce((a, b) => a + b);
                    averagePrice = total / items.length;
                  }

                  final suspiciousItems = items
                      .where((item) =>
                          (item['price'] as num).toDouble() > averagePrice * 3)
                      .toList();

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Suspicious Listings'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suspiciousItems.length,
                            itemBuilder: (context, index) {
                              final item = suspiciousItems[index];
                              return ListTile(
                                title: Text(item['title'] ?? ''),
                                subtitle: Text(
                                    '₱${item['price'].toStringAsFixed(2)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await _adminService
                                        .removeMarketItem(item['id']);
                                    Navigator.pop(context);
                                    _loadMarketItems();
                                    _loadMarketStats();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

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
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                transaction['imageUrl'],
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TODO: Add category distribution chart
                  const Center(
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

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Settings'),
            subtitle: const Text('Configure marketplace notifications'),
            onTap: () {
              // TODO: Implement notification settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security Settings'),
            subtitle: const Text('Configure marketplace security'),
            onTap: () {
              // TODO: Implement security settings
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Category Management'),
            subtitle: const Text('Manage marketplace categories'),
            onTap: () {
              // TODO: Implement category management
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('Marketplace Policies'),
            subtitle: const Text('Update marketplace rules and policies'),
            onTap: () {
              // TODO: Implement policy management
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out from admin panel'),
            onTap: _signOut,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
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
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      drawer: const AdminDrawer(),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildListingsTab(),
            _buildAnalyticsTab(),
            _buildSettingsTab(),
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
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
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
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF00C49A)),
                  onPressed: _bulkAction,
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
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.error),
                                          );
                                        },
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
                                          color: isSold
                                              ? Colors.red[50]
                                              : Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isSold ? 'Sold' : 'Active',
                                          style: TextStyle(
                                            color: isSold
                                                ? Colors.red
                                                : Colors.green,
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
}

class _SalesData {
  final String day;
  final double value;

  _SalesData(this.day, this.value);
}
