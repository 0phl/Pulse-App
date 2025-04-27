import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/market_item.dart';
import '../services/market_service.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/confirmation_dialog.dart';

class SellerDashboardPage extends StatefulWidget {
  final int initialTabIndex;

  const SellerDashboardPage({Key? key, this.initialTabIndex = 0})
      : super(key: key);

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage>
    with SingleTickerProviderStateMixin {
  final MarketService _marketService = MarketService();
  late TabController _tabController;
  bool _isLoading = true;

  // Search and filtering
  String _currentFilter = 'all';
  TextEditingController _searchController = TextEditingController();

  // Refresh controllers for different tabs
  RefreshController _overviewRefreshController =
      RefreshController(initialRefresh: false);
  RefreshController _pendingRefreshController =
      RefreshController(initialRefresh: false);
  RefreshController _rejectedRefreshController =
      RefreshController(initialRefresh: false);
  RefreshController _soldRefreshController =
      RefreshController(initialRefresh: false);

  // Theme mode
  bool _isDarkMode = false;

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

  // Theme data
  final _appTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF00C49A),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF00C49A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: Colors.white,
    dividerColor: Colors.grey[200],
  );

  // Simplified helper methods to replace _isDarkMode ternary expressions
  Color get textPrimaryColor => const Color(0xFF2D3748);
  Color get textSecondaryColor => const Color(0xFF718096);
  Color get cardBackgroundColor => Colors.white;
  Color get dividerColor => Colors.grey[200]!;
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTabIndex);

    // Add listener to track tab changes
    _tabController.addListener(_handleTabChange);

    _initializeStreams();
    _loadSellerData();

    _searchController.addListener(() {
      setState(() {
        // This will trigger a rebuild when search text changes
      });
    });
  }

  // Flag to prevent unwanted tab changes
  bool _isTabLocked = false;
  int _lockedTabIndex = 0;

  // Track tab changes
  void _handleTabChange() {
    // Only handle tab changes when the controller is actually changing tabs
    if (_tabController.indexIsChanging) {
      final newIndex = _tabController.index;

      // If tab is locked, prevent the change
      if (_isTabLocked && newIndex != _lockedTabIndex) {
        // Immediately jump back to the locked tab without animation
        _tabController.index = _lockedTabIndex;

        // Also use post-frame callback as a backup to ensure we stay on the locked tab
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isTabLocked) {
            if (_tabController.index != _lockedTabIndex) {
              _tabController.index = _lockedTabIndex;
            }
          }
        });
      }
    }
  }

  // Helper method to safely unlock the tab with a delay
  Future<void> _safelyUnlockTab() async {
    // Add a small delay before unlocking to ensure any pending tab changes are processed
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      final currentTab = _tabController.index;
      if (currentTab != _lockedTabIndex) {
        _tabController.index = _lockedTabIndex;

        // Add another small delay to ensure the tab is restored
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isTabLocked = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments with an initialTabIndex
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('initialTabIndex')) {
      final initialTabIndex = arguments['initialTabIndex'] as int;
      if (initialTabIndex >= 0 &&
          initialTabIndex < 4 &&
          _tabController.index != initialTabIndex) {
        _tabController.animateTo(initialTabIndex);
      }
    }
  }

  void _initializeStreams() {
    try {
      _pendingItemsStream =
          _marketService.getSellerItemsByStatusStream('pending');
      // We don't need the approved items stream for now
      _rejectedItemsStream =
          _marketService.getSellerItemsByStatusStream('rejected');
      _soldItemsStream = _marketService.getSellerSoldItemsStream();
    } catch (e) {
      // Log error
      debugPrint('Error initializing streams: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _overviewRefreshController.dispose();
    _pendingRefreshController.dispose();
    _rejectedRefreshController.dispose();
    _soldRefreshController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    try {
      // Store current tab index before loading
      final currentTab = _tabController.index;

      // Lock the tab to prevent unwanted changes during data loading
      final wasTabAlreadyLocked = _isTabLocked;

      if (!wasTabAlreadyLocked) {
        _isTabLocked = true;
        _lockedTabIndex = currentTab;
      }

      setState(() {
        _isLoading = true;
      });

      // Load seller dashboard stats
      final stats = await _marketService.getSellerDashboardStats();

      // Ensure dailySales data exists for chart
      if (stats['dailySales'] == null || (stats['dailySales'] as Map).isEmpty) {
        // Generate some sample sales data for the last 7 days
        final Map<String, dynamic> sampleDailySales = {};
        final now = DateTime.now();

        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dateString = DateFormat('yyyy-MM-dd').format(date);

          // Create random sales values between 0 and 500
          final saleValue = i == 3
              ? 350.0
              : // Higher value in the middle
              i == 1
                  ? 450.0
                  : // Recent spike
                  Random().nextDouble() * 200; // Random values

          sampleDailySales[dateString] = saleValue;
        }

        // Add sample data to stats
        stats['dailySales'] = sampleDailySales;
      }

      // Load items by status
      final pendingItems =
          await _marketService.getSellerItemsByStatus('pending');
      final approvedItems =
          await _marketService.getSellerItemsByStatus('approved');
      final rejectedItems =
          await _marketService.getSellerItemsByStatus('rejected');
      final soldItems = await _marketService.getSellerSoldItems();

      // Load seller rating info
      final ratingInfo = await _marketService.getSellerRatingInfo();

      if (mounted) {
        // Check if tab changed during data loading
        final tabChanged = _tabController.index != currentTab;

        if (tabChanged) {
          // Force tab back to where it should be
          _tabController.index = currentTab;
        }

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

        // Complete refresh for the current tab's controller only
        switch (currentTab) {
          case 0:
            _overviewRefreshController.refreshCompleted();
            break;
          case 1:
            _pendingRefreshController.refreshCompleted();
            break;
          case 2:
            _rejectedRefreshController.refreshCompleted();
            break;
          case 3:
            _soldRefreshController.refreshCompleted();
            break;
        }

        // Double-check that we're still on the correct tab after data reload
        if (_tabController.index != currentTab) {
          // Use a post-frame callback to ensure the tab change happens after the state update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tabController.index = currentTab;
            }
          });
        }

        // Only unlock the tab if we locked it in this method
        if (!wasTabAlreadyLocked) {
          // Use a post-frame callback to ensure any pending tab changes are processed
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              await Future.delayed(const Duration(milliseconds: 100));
              _isTabLocked = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading seller data: $e')),
        );
        setState(() {
          _isLoading = false;
        });

        // Complete refresh with error for all controllers if it was triggered by pull-to-refresh
        _overviewRefreshController.refreshFailed();
        _pendingRefreshController.refreshFailed();
        _rejectedRefreshController.refreshFailed();
        _soldRefreshController.refreshFailed();
      }
    }
  }

  void _onRefresh() async {
    await _loadSellerData();
  }

  // Helper method to get the appropriate refresh controller based on the stream
  RefreshController _getRefreshControllerForTab(
      Stream<List<MarketItem>>? itemsStream) {
    if (itemsStream == _pendingItemsStream) {
      return _pendingRefreshController;
    } else if (itemsStream == _rejectedItemsStream) {
      return _rejectedRefreshController;
    } else if (itemsStream == _soldItemsStream) {
      return _soldRefreshController;
    } else {
      // Default to overview controller if stream doesn't match any known stream
      return _overviewRefreshController;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _appTheme,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Seller Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          backgroundColor: const Color(0xFF00C49A),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Pending'),
              Tab(text: 'Rejected'),
              Tab(text: 'Sold'),
            ],
          ),
        ),
        body: _isLoading
            ? const ModernShimmerLoading()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildItemsStreamTab(_pendingItemsStream, 'No pending items'),
                  _buildItemsStreamTab(
                      _rejectedItemsStream, 'No rejected items'),
                  _buildItemsStreamTab(_soldItemsStream, 'No sold items'),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Navigate to add new item page
            Navigator.pushNamed(context, '/add_item')
                .then((_) => _loadSellerData());
          },
          backgroundColor: const Color(0xFF00C49A),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return SmartRefresher(
      controller: _overviewRefreshController,
      onRefresh: _onRefresh,
      header: const WaterDropHeader(
        waterDropColor: Color(0xFF00C49A),
        complete: Icon(
          Icons.check,
          color: Color(0xFF00C49A),
        ),
      ),
      // Enable scrolling in the SmartRefresher
      enablePullDown: true,
      // This is the key fix - we need to make the SmartRefresher scrollable
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Actions
          _buildQuickActions(),

          const SizedBox(height: 16),

          // Seller Rating Card
          _buildDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Seller Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimaryColor,
                          ),
                        ),
                        Text(
                          '($_totalRatings ${_totalRatings == 1 ? 'review' : 'reviews'})',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sales Chart
          _buildSalesChart(),

          const SizedBox(height: 16),

          // Sales Summary Card
          _buildDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow(
                  'Total Revenue',
                  currencyFormat.format(_dashboardStats['totalRevenue'] ?? 0),
                  Icons.account_balance_wallet,
                  const Color(0xFF10B981),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                _buildStatRow(
                  'Items Sold',
                  '${_dashboardStats['itemsSold'] ?? 0}',
                  Icons.shopping_bag_outlined,
                  const Color(0xFF3B82F6),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                _buildStatRow(
                  'Average Item Price',
                  currencyFormat.format(_dashboardStats['averagePrice'] ?? 0),
                  Icons.trending_up_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Items Status Card
          _buildDashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildItemStatusRow(
                  'Pending Approval',
                  '${_pendingItems.length}',
                  Icons.pending_outlined,
                  const Color(0xFFF59E0B),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                _buildItemStatusRow(
                  'Active Listings',
                  '${_approvedItems.length}',
                  Icons.check_circle_outline,
                  const Color(0xFF10B981),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                _buildItemStatusRow(
                  'Rejected Items',
                  '${_rejectedItems.length}',
                  Icons.cancel_outlined,
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recent Activity Card
          if (_dashboardStats['recentActivity'] != null &&
              (_dashboardStats['recentActivity'] as List).isNotEmpty)
            _buildDashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildRecentActivityList(),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Recent Sold Items Card
          if (_soldItems.isNotEmpty)
            _buildDashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (_soldItems.length > 3)
                        TextButton(
                          onPressed: () {
                            _tabController.animateTo(3); // Navigate to Sold tab
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00C49A),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'View all',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    _soldItems.length > 3 ? 3 : _soldItems.length,
                    (index) {
                      final item = _soldItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (item.imageUrls.isNotEmpty) {
                                  _openImageGallery(item.imageUrls, 0);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.imageUrls.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrls[0],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF00C49A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: Colors.grey[200],
                                          child: Icon(Icons.error,
                                              color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.grey),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: textPrimaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currencyFormat.format(item.price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(
                                        _getDateTime(item.createdAt,
                                            item: item)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemStatusRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textSecondaryColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
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
          activityIcon = Icons.check_circle_outline;
          activityColor = const Color(0xFF10B981);
          break;
        case 'item_rejected':
          activityIcon = Icons.cancel_outlined;
          activityColor = const Color(0xFFEF4444);
          break;
        case 'item_sold':
          activityIcon = Icons.shopping_bag_outlined;
          activityColor = const Color(0xFF3B82F6);
          break;
        case 'new_rating':
          activityIcon = Icons.star_outline;
          activityColor = const Color(0xFFF59E0B);
          break;
        default:
          activityIcon = Icons.notifications_none_rounded;
          activityColor = const Color(0xFF718096);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: activityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                activityIcon,
                color: activityColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['message'] ?? 'Activity',
                    style: TextStyle(
                      fontSize: 14,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondaryColor,
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

  Widget _buildItemsStreamTab(
      Stream<List<MarketItem>>? itemsStream, String emptyMessage) {
    if (itemsStream == null) {
      return const Center(child: Text('Error loading data'));
    }

    return StreamBuilder<List<MarketItem>>(
      stream: itemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00C49A),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }

        var items = snapshot.data ?? [];

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          items = items
              .where((item) =>
                  item.title.toLowerCase().contains(searchTerm) ||
                  item.description.toLowerCase().contains(searchTerm))
              .toList();
        }

        // Apply sorting
        switch (_currentFilter) {
          case 'recent':
            items.sort((a, b) =>
                _getDateTime(b.createdAt).compareTo(_getDateTime(a.createdAt)));
            break;
          case 'oldest':
            items.sort((a, b) =>
                _getDateTime(a.createdAt).compareTo(_getDateTime(b.createdAt)));
            break;
          case 'price_desc':
            items.sort((a, b) => b.price.compareTo(a.price));
            break;
          case 'price_asc':
            items.sort((a, b) => a.price.compareTo(b.price));
            break;
        }

        if (items.isEmpty) {
          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No items match your search'
                            : emptyMessage,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_searchController.text.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                          },
                          child: const Text('Clear Search'),
                        )
                      else
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/add_item');
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add New Item'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00C49A),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: SmartRefresher(
                controller: _getRefreshControllerForTab(itemsStream),
                onRefresh: _onRefresh,
                header: const WaterDropHeader(
                  waterDropColor: Color(0xFF00C49A),
                  complete: Icon(
                    Icons.check,
                    color: Color(0xFF00C49A),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildModernItemCard(item);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey[200]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C49A)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Recent', 'recent'),
                _buildFilterChip('Price: High to Low', 'price_desc'),
                _buildFilterChip('Price: Low to High', 'price_asc'),
                _buildFilterChip('Oldest', 'oldest'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C49A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C49A) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildModernItemCard(MarketItem item) {
    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    // Determine status badge color
    Color statusColor;
    IconData statusIcon;
    String statusText = item.status.toUpperCase();

    switch (item.status) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_outlined;
        break;
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    if (item.isSold) {
      statusColor = const Color(0xFF3B82F6);
      statusIcon = Icons.shopping_bag_outlined;
      statusText = "SOLD";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image and status badge
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (item.imageUrls.isNotEmpty) {
                    _openImageGallery(item.imageUrls, 0);
                  }
                },
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl:
                          item.imageUrls.isNotEmpty ? item.imageUrls[0] : '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00C49A),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
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
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                      color: Colors.black.withOpacity(0.4),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'SOLD',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Item details
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currencyFormat.format(item.price),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondaryColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Show rejection reason if item is rejected
                if (item.status == 'rejected' && item.rejectionReason != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFFEF4444),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Rejection Reason:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.rejectionReason!,
                          style: TextStyle(
                            color: const Color(0xFFEF4444),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Item actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (item.status == 'rejected')
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Resubmit'),
                        onPressed: () => _resubmitItem(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    if (item.status != 'approved' || !item.isSold)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          onPressed: () => _confirmRemoveItem(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
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

  // New methods for the enhanced features

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Item',
                onTap: () => Navigator.pushNamed(context, '/add_item'),
              ),
              _buildActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Inventory',
                onTap: () => _tabController.animateTo(0),
              ),
              _buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                onTap: () {
                  // Navigate to analytics page
                  // Navigator.pushNamed(context, '/analytics');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Analytics feature coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildActionButton(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  // Navigate to settings page
                  // Navigator.pushNamed(context, '/settings');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings feature coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF00C49A),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    // Extract daily sales data from _dashboardStats
    final Map<String, dynamic> dailySales = _dashboardStats['dailySales'] ?? {};

    // Convert to a list of FlSpots for the chart
    List<FlSpot> spots = [];
    List<String> dates = []; // Store dates for tooltip
    double maxValue = 0; // Track max value for Y axis scaling

    // Get the dates in chronological order
    final dateStrings = dailySales.keys.toList();
    dateStrings.sort(); // Sort dates

    // Only show up to 7 days
    final int numberOfDays = min(dateStrings.length, 7);

    // Generate spots for each date
    for (int i = 0; i < numberOfDays; i++) {
      final dateString = dateStrings[i];
      final value = (dailySales[dateString] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      dates.add(dateString);
      if (value > maxValue) {
        maxValue = value;
      }
    }

    // If no data is available, create some dummy data
    if (spots.isEmpty) {
      // Generate dates for the last 7 days
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        dates.add(dateString);

        // Add a spot with 0 value
        spots.add(FlSpot((6 - i).toDouble(), 0));
      }
    }

    // Return the sales chart widget
    return _buildDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 100 ? 100 : 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < dates.length) {
                          // Parse the date and get the day
                          final date = DateTime.parse(dates[value.toInt()]);
                          final day = date.day.toString();

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              day,
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: const Text(''),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        // Show abbreviated price on y-axis
                        String text = '';
                        if (value == 0) {
                          text = '₱0';
                        } else if (value >= 1000) {
                          text = '₱${(value / 1000).toStringAsFixed(0)}K';
                        } else {
                          text = '₱${value.toInt()}';
                        }

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            text,
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    left: BorderSide(color: Colors.grey[200]!, width: 1),
                    // Hide top and right borders
                    top: BorderSide.none,
                    right: BorderSide.none,
                  ),
                ),
                minX: 0,
                maxX: max(
                    6,
                    (numberOfDays - 1)
                        .toDouble()), // X-axis for 7 days (0 to 6)
                minY: 0,
                maxY: maxValue == 0
                    ? 50
                    : maxValue * 1.2, // Dynamic Y max + padding, minimum 50
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, // Use the processed daily sales spots
                    isCurved: true,
                    gradient: LinearGradient(
                      // Use gradient for line color
                      colors: [
                        const Color(0xFF00C49A),
                        Colors.tealAccent.shade700
                      ],
                    ),
                    barWidth: 3, // Slightly thinner line
                    isStrokeCapRound: true,
                    dotData:
                        const FlDotData(show: true), // Show dots on the line
                    belowBarData: BarAreaData(
                      // Add gradient below line
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00C49A).withOpacity(0.3),
                          Colors.tealAccent.shade700.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true, // Enable default touch behaviors
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white.withOpacity(0.8),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;

                        // Parse date to display in a more readable format
                        final dateIndex = flSpot.x.toInt();
                        if (dateIndex >= 0 && dateIndex < dates.length) {
                          final dateString = dates[dateIndex];
                          final date = DateTime.parse(dateString);
                          final formattedDate =
                              DateFormat('MMM d, yyyy').format(date);

                          return LineTooltipItem(
                            '$formattedDate\n', // Date on first line
                            TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '₱${NumberFormat('#,##0.00').format(flSpot.y)}', // Sales amount
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImageGallery(List<String> imageUrls, int initialIndex) {
    // Store the current tab index before navigating
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    _isTabLocked = true;
    _lockedTabIndex = currentTab;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryPage(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          isDarkMode: false, // Always use light mode
          sourceTab: currentTab, // Pass the source tab to the gallery
        ),
      ),
    ).then((_) async {
      // Ensure we're on the correct tab when returning
      if (mounted) {
        if (_tabController.index != currentTab) {
          _tabController.index =
              currentTab; // Use direct index assignment for immediate effect
        }

        // Safely unlock the tab with delay to prevent unwanted tab changes
        await _safelyUnlockTab();
      }
    });

    // Set a post-frame callback to check if the tab changed immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final tabChanged = _tabController.index != currentTab;
        if (tabChanged) {
          _tabController.index =
              currentTab; // Use direct index assignment for immediate effect
        }
      }
    });
  }

  Future<void> _resubmitItem(MarketItem item) async {
    // Store the current tab index before proceeding
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    _isTabLocked = true;
    _lockedTabIndex = currentTab;

    try {
      // Create a new item with the same details but reset the status
      final updatedItem = MarketItem(
        id: item.id,
        title: item.title,
        price: item.price,
        description: item.description,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
        imageUrls: item.imageUrls,
        communityId: item.communityId,
        status: 'pending', // Reset to pending
        rejectionReason: null, // Clear rejection reason
      );

      await _marketService.updateMarketItem(updatedItem);

      if (mounted) {
        // Check if tab changed unexpectedly
        final tabChanged = _tabController.index != currentTab;
        if (tabChanged) {
          _tabController.index =
              currentTab; // Use direct index assignment for immediate effect
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item resubmitted for approval'),
            backgroundColor: Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh data
        await _loadSellerData();

        // Double-check that we're still on the correct tab after data reload
        if (mounted) {
          final tabChangedAfterReload = _tabController.index != currentTab;
          if (tabChangedAfterReload) {
            _tabController.index =
                currentTab; // Use direct index assignment for immediate effect
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resubmitting item: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Safely unlock the tab with delay to prevent unwanted tab changes
      if (mounted) {
        await _safelyUnlockTab();
      }
    }
  }

  Future<void> _confirmRemoveItem(MarketItem item) async {
    // Store the current tab index before showing the dialog
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    _isTabLocked = true;
    _lockedTabIndex = currentTab;

    final result = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Item',
      message:
          'Are you sure you want to remove this item? This action cannot be undone.',
      confirmText: 'Remove',
      cancelText: 'Cancel',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.delete_forever_rounded,
      iconBackgroundColor: const Color(0xFFEF4444),
    );

    // Check if the tab changed during dialog display
    if (mounted) {
      final tabChanged = _tabController.index != currentTab;
      if (tabChanged) {
        // If tab changed unexpectedly, restore it immediately
        _tabController.index = currentTab;
      }
    }

    if (result == true) {
      try {
        await _marketService.deleteMarketItem(item.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item removed successfully'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Refresh data while preserving tab index
          await _loadSellerData();

          // Double-check that we're still on the correct tab after data reload
          if (mounted) {
            final tabChangedAfterReload = _tabController.index != currentTab;
            if (tabChangedAfterReload) {
              _tabController.index =
                  currentTab; // Use direct index assignment for immediate effect
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing item: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    // Safely unlock the tab with delay to prevent unwanted tab changes
    if (mounted) {
      await _safelyUnlockTab();
    }
  }
}

// Gallery Page for viewing images
class GalleryPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool isDarkMode;
  final int sourceTab; // Add source tab parameter

  const GalleryPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.isDarkMode = false,
    this.sourceTab = 0, // Default to overview tab
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handle back button press to ensure proper navigation
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            '${_currentIndex + 1}/${widget.imageUrls.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
        body: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider:
                  CachedNetworkImageProvider(widget.imageUrls[index]),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          },
          itemCount: widget.imageUrls.length,
          loadingBuilder: (context, event) => Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded /
                        (event.expectedTotalBytes ?? 1),
                color: const Color(0xFF00C49A),
              ),
            ),
          ),
          backgroundDecoration: const BoxDecoration(
            color: Colors.black,
          ),
          pageController: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class ModernShimmerLoading extends StatelessWidget {
  const ModernShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Use a ListView with shrinkWrap: true to avoid overflow
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // Reduced vertical padding
      // Make sure the ListView doesn't try to be as big as its children
      shrinkWrap: true,
      // Add physics to make it scrollable
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildLoadingCard(80), // Quick actions (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildLoadingCard(60), // Rating card (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildLoadingCard(120), // Chart (further reduced height)
        const SizedBox(height: 12), // Reduced spacing
        _buildStatsLoadingCard(isDarkMode), // Stats card
        const SizedBox(height: 12), // Reduced spacing
        _buildItemsLoadingCard(isDarkMode), // Items card
        const SizedBox(height: 12), // Reduced spacing
        _buildListLoadingCard(isDarkMode), // Activity list
      ],
    );
  }

  Widget _buildLoadingCard(double height) {
    return Builder(builder: (context) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

      return Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
      );
    });
  }

  Widget _buildStatsLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      // Remove fixed height to allow content to determine size
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                children: [
                  Container(
                    width: 32, // Smaller size
                    height: 32, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Container(
                      height: 12, // Smaller height
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Container(
                    width: 50, // Smaller width
                    height: 12, // Smaller height
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      // Remove fixed height to allow content to determine size
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                children: [
                  Container(
                    width: 32, // Smaller size
                    height: 32, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced spacing
                        Container(
                          width: 80, // Smaller width
                          height: 8, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
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
    );
  }

  Widget _buildListLoadingCard(bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Container(
      // Remove fixed height to allow content to determine size
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12), // Reduced spacing
          // Generate only 2 items instead of 3
          ...List.generate(
            2, // Reduced from 3 to 2
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8), // Reduced padding
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20, // Smaller size
                    height: 20, // Smaller size
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced spacing
                        Container(
                          width: 60, // Smaller width
                          height: 8, // Smaller height
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
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
    );
  }
}
