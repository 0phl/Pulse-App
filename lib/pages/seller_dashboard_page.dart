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
import 'package:firebase_auth/firebase_auth.dart';

// Models and services
import '../models/market_item.dart';
import '../services/market_service.dart';

// Widgets
import '../widgets/shimmer_loading.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/item_card_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/gallery_page.dart';
import '../widgets/modern_shimmer_loading.dart';

// Utils
import '../utils/dashboard_utils.dart';

// Pages
import '../pages/seller_profile_page.dart';

class SellerDashboardPage extends StatefulWidget {
  final int initialTabIndex;

  const SellerDashboardPage({super.key, this.initialTabIndex = 0});

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage>
    with SingleTickerProviderStateMixin, TabLockMixin {
  final MarketService _marketService = MarketService();
  late TabController _tabController;
  bool _isLoading = true;

  // Search and filtering
  String _currentFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Refresh controllers for different tabs
  final RefreshController _overviewRefreshController =
      RefreshController(initialRefresh: false);
  final RefreshController _pendingRefreshController =
      RefreshController(initialRefresh: false);
  final RefreshController _rejectedRefreshController =
      RefreshController(initialRefresh: false);
  final RefreshController _soldRefreshController =
      RefreshController(initialRefresh: false);

  // Theme mode
  final bool _isDarkMode = false;

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
  Stream<Map<String, dynamic>>? _dailySalesStream;

  // Current time period for sales chart
  TimePeriod _currentTimePeriod = TimePeriod.week;

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

    _tabController.addListener(() => handleTabChange(_tabController));

    _initializeStreams();
    _loadSellerData();

    _searchController.addListener(() {
      setState(() {
        // This will trigger a rebuild when search text changes
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

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
      _updateDailySalesStream();
    } catch (e) {
      // Log error
      debugPrint('Error initializing streams: $e');
    }
  }

  void _updateDailySalesStream() {
    final now = DateTime.now();
    DateTime? startDate;

    switch (_currentTimePeriod) {
      case TimePeriod.week:
        startDate = now.subtract(const Duration(days: 6)); // Last 7 days
        break;
      case TimePeriod.month:
        startDate = now.subtract(const Duration(days: 29)); // Last 30 days
        break;
      case TimePeriod.threeMonths:
        startDate = DateTime(now.year, now.month - 3, now.day); // Last 3 months
        break;
      case TimePeriod.sixMonths:
        startDate = DateTime(now.year, now.month - 6, now.day); // Last 6 months
        break;
      case TimePeriod.year:
        startDate = DateTime(now.year - 1, now.month, now.day); // Last year
        break;
    }

    final daysDifference = now.difference(startDate).inDays + 1;

    _dailySalesStream = _marketService.getDailySalesDataStream(
      customStartDate: startDate,
      customEndDate: now,
      defaultDays: daysDifference,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(() => handleTabChange(_tabController));
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
      final currentTab = _tabController.index;

      // Lock the tab to prevent unwanted changes during data loading
      final wasTabAlreadyLocked = isTabLocked;

      if (!wasTabAlreadyLocked) {
        setIsTabLocked(true);
        setLockedTabIndex(currentTab);
      }

      setState(() {
        _isLoading = true;
      });

      final stats = await _marketService.getSellerDashboardStats();

      // Ensure dailySales data exists for chart
      if (stats['dailySales'] == null || (stats['dailySales'] as Map).isEmpty) {
        // Generate some sample sales data for the last 7 days
        final Map<String, dynamic> sampleDailySales = {};
        final now = DateTime.now();

        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dateString = DateFormat('yyyy-MM-dd').format(date);

          final saleValue = i == 3
              ? 350.0
              : // Higher value in the middle
              i == 1
                  ? 450.0
                  : // Recent spike
                  Random().nextDouble() * 200; // Random values

          sampleDailySales[dateString] = saleValue;
        }

        stats['dailySales'] = sampleDailySales;
      }

      final pendingItems =
          await _marketService.getSellerItemsByStatus('pending');
      final approvedItems =
          await _marketService.getSellerItemsByStatus('approved');
      final rejectedItems =
          await _marketService.getSellerItemsByStatus('rejected');
      final soldItems = await _marketService.getSellerSoldItems();

      final ratingInfo = await _marketService.getSellerRatingInfo();

      if (mounted) {
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tabController.index = currentTab;
            }
          });
        }

        // Only unlock the tab if we locked it in this method
        if (!wasTabAlreadyLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              await Future.delayed(const Duration(milliseconds: 100));
              setIsTabLocked(false);
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
          // Seller Rating Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellerProfilePage(
                        sellerId: currentUser.uid,
                        sellerName: 'My Profile',
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: DashboardWidgets.buildDashboardCard(
                cardBackgroundColor: cardBackgroundColor,
                cardShadow: cardShadow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Seller Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Color(0xFF718096),
                        ),
                      ],
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
            ),
          ),

          const SizedBox(height: 16),

          // Sales Chart - Use real-time stream
          _buildSalesChartSection(),

          const SizedBox(height: 16),

          // Sales Summary Card
          DashboardWidgets.buildDashboardCard(
            cardBackgroundColor: cardBackgroundColor,
            cardShadow: cardShadow,
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
                DashboardWidgets.buildStatRow(
                  'Total Revenue',
                  currencyFormat.format(_dashboardStats['totalRevenue'] ?? 0),
                  Icons.account_balance_wallet,
                  const Color(0xFF10B981),
                  textSecondaryColor,
                  textPrimaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                DashboardWidgets.buildStatRow(
                  'Items Sold',
                  '${_dashboardStats['itemsSold'] ?? 0}',
                  Icons.shopping_bag_outlined,
                  const Color(0xFF3B82F6),
                  textSecondaryColor,
                  textPrimaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                DashboardWidgets.buildStatRow(
                  'Average Item Price',
                  currencyFormat.format(_dashboardStats['averagePrice'] ?? 0),
                  Icons.trending_up_rounded,
                  const Color(0xFF8B5CF6),
                  textSecondaryColor,
                  textPrimaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Items Status Card
          DashboardWidgets.buildDashboardCard(
            cardBackgroundColor: cardBackgroundColor,
            cardShadow: cardShadow,
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
                DashboardWidgets.buildItemStatusRow(
                  'Pending Approval',
                  '${_pendingItems.length}',
                  Icons.pending_outlined,
                  const Color(0xFFF59E0B),
                  textSecondaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                DashboardWidgets.buildItemStatusRow(
                  'Active Listings',
                  '${_approvedItems.length}',
                  Icons.check_circle_outline,
                  const Color(0xFF10B981),
                  textSecondaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                DashboardWidgets.buildItemStatusRow(
                  'Rejected Items',
                  '${_rejectedItems.length}',
                  Icons.cancel_outlined,
                  const Color(0xFFEF4444),
                  textSecondaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recent Activity Card
          if (_dashboardStats['recentActivity'] != null &&
              (_dashboardStats['recentActivity'] as List).isNotEmpty)
            DashboardWidgets.buildDashboardCard(
              cardBackgroundColor: cardBackgroundColor,
              cardShadow: cardShadow,
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
                  ...DashboardWidgets.buildRecentActivityList(
                    Map<String, dynamic>.from(_dashboardStats)..['recentActivity'] = 
                        (_dashboardStats['recentActivity'] as List).take(5).toList(),
                    textPrimaryColor,
                    textSecondaryColor,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Recent Sold Items Card
          if (_soldItems.isNotEmpty)
            DashboardWidgets.buildDashboardCard(
              cardBackgroundColor: cardBackgroundColor,
              cardShadow: cardShadow,
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
                                          child: const Icon(Icons.error,
                                              color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image_not_supported,
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('MMM d, yyyy').format(
                                            DashboardUtils.getDateTime(
                                                item.createdAt,
                                                item: item)),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                      if (item.isSold && item.soldAt != null)
                                        Text(
                                          'Sold: ${DateFormat('MMM d, yyyy').format(item.soldAt!)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
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
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesChartSection() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dailySalesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return DashboardWidgets.buildDashboardCard(
            cardBackgroundColor: cardBackgroundColor,
            cardShadow: cardShadow,
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
                const SizedBox(
                  height: 240,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C49A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return DashboardWidgets.buildDashboardCard(
            cardBackgroundColor: cardBackgroundColor,
            cardShadow: cardShadow,
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
                  child: Center(
                    child: Text(
                      'Error loading sales data',
                      style: TextStyle(color: textSecondaryColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final dailySales = snapshot.data ?? _dashboardStats['dailySales'] ?? {};

        final updatedDashboardStats =
            Map<String, dynamic>.from(_dashboardStats);
        updatedDashboardStats['dailySales'] = dailySales;

        // Call the chart widget with updated data
        return SalesChartWidget.buildSalesChart(
          updatedDashboardStats,
          textPrimaryColor,
          textSecondaryColor,
          cardBackgroundColor,
          cardShadow,
          defaultTimePeriod: _currentTimePeriod,
          onTimePeriodChanged: (TimePeriod period) {
            setState(() {
              _currentTimePeriod = period;
              _updateDailySalesStream();
            });
          },
        );
      },
    );
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
            items.sort((a, b) => DashboardUtils.getDateTime(b.createdAt)
                .compareTo(DashboardUtils.getDateTime(a.createdAt)));
            break;
          case 'oldest':
            items.sort((a, b) => DashboardUtils.getDateTime(a.createdAt)
                .compareTo(DashboardUtils.getDateTime(b.createdAt)));
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
              DashboardWidgets.buildFilterBar(
                _searchController,
                _currentFilter,
                (value) {
                  setState(() {
                    _currentFilter = value;
                  });
                },
              ),
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
            DashboardWidgets.buildFilterBar(
              _searchController,
              _currentFilter,
              (value) {
                setState(() {
                  _currentFilter = value;
                });
              },
            ),
            Expanded(
              child: SmartRefresher(
                controller: DashboardUtils.getRefreshControllerForTab(
                  itemsStream,
                  _pendingItemsStream!,
                  _rejectedItemsStream!,
                  _soldItemsStream!,
                  _overviewRefreshController,
                  _pendingRefreshController,
                  _rejectedRefreshController,
                  _soldRefreshController,
                ),
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
                    return ItemCardWidget.buildModernItemCard(
                      item,
                      textPrimaryColor,
                      textSecondaryColor,
                      (item) {
                        if (item.imageUrls.isNotEmpty) {
                          _openImageGallery(item.imageUrls, 0);
                        }
                      },
                      _resubmitItem,
                      _confirmRemoveItem,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openImageGallery(List<String> imageUrls, int initialIndex) {
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    setIsTabLocked(true);
    setLockedTabIndex(currentTab);

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
        await DashboardUtils.safelyUnlockTab(
          _tabController,
          mounted,
          currentTab,
          setIsTabLocked,
        );
      }
    });

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
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    setIsTabLocked(true);
    setLockedTabIndex(currentTab);

    try {
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
        await DashboardUtils.safelyUnlockTab(
          _tabController,
          mounted,
          currentTab,
          setIsTabLocked,
        );
      }
    }
  }

  Future<void> _confirmRemoveItem(MarketItem item) async {
    final currentTab = _tabController.index;

    // Lock the tab to prevent unwanted changes
    setIsTabLocked(true);
    setLockedTabIndex(currentTab);

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
      await DashboardUtils.safelyUnlockTab(
        _tabController,
        mounted,
        currentTab,
        setIsTabLocked,
      );
    }
  }
}
