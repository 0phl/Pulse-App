import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/statistics_card.dart';
import '../../widgets/improved_kpi_card.dart';
import '../../widgets/recent_reports_widget.dart';
import '../../widgets/shimmer_loading.dart';
import '../../models/report.dart';
import './admin_drawer.dart';
import './marketplace_page.dart';
import 'package:PULSE/widgets/engagement_report_card.dart';
import '../../widgets/admin_scaffold.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _authService = AuthService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _communityStats;
  Map<String, dynamic>? _activityStats;
  String _communityName = '';
  bool _isLoading = true;
  List<Report> _recentReports = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _loadCommunityAndStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityAndStats() async {
    setState(() => _isLoading = true);
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null) {
        setState(() => _communityName = community.name);
      }
      await _loadStats();
      await _loadRecentReports();
      _controller.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading community: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentReports() async {
    try {
      // Get the first 5 reports from the stream
      final reportsStream = _adminService.getReports();
      final reports = await reportsStream.first;

      if (mounted) {
        setState(() {
          _recentReports = reports.take(5).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // Load each stat individually to prevent one failure from affecting others
      Map<String, dynamic>? userStats;
      Map<String, dynamic>? communityStats;
      Map<String, dynamic>? activityStats;

      try {
        userStats = await _adminService.getUserStats();
        // Get pending users count (filter out rejected users)
        final pendingAndRejectedUsers = await _adminService.getPendingVerificationUsers();
        // Only count users with 'pending' status, not 'rejected'
        final onlyPendingUsers = pendingAndRejectedUsers.where((user) => user.verificationStatus == 'pending').toList();
        userStats = {
          ...userStats,
          'pendingUsers': onlyPendingUsers.length,
          'newPendingUsers': onlyPendingUsers
              .where((user) => user.createdAt
                  .isAfter(DateTime.now().subtract(const Duration(days: 7))))
              .length,
        };
      } catch (e) {
        // Error loading user stats
        // Use default values if this fails
        userStats = {
          'communityUsers': 4,
          'newUsersThisWeek': 0,
          'pendingUsers': 0,
          'newPendingUsers': 0,
        };
      }

      try {
        communityStats = await _adminService.getCommunityStats();
        // Community stats loaded successfully
      } catch (e) {
        // Error loading community stats
        // Use default values if this fails
        communityStats = {
          'membersCount': 4,
          'activeUsers': 1,
          'engagementRate': 25,
        };
      }

      try {
        activityStats = await _adminService.getActivityStats();
        // Get reports stream to count new reports today
        final reportsStream = await _adminService.getReports().first;
        final today = DateTime.now();
        final newReportsCount = reportsStream
            .where((report) =>
                report.createdAt.year == today.year &&
                report.createdAt.month == today.month &&
                report.createdAt.day == today.day)
            .length;

        activityStats = {
          ...activityStats,
          'newReportsToday': newReportsCount,
        };
      } catch (e) {
        // Error loading activity stats
        // Use default values if this fails
        activityStats = {
          'totalReports': 0,
          'dailyActivity': List<int>.filled(7, 0),
          'newPostsToday': 0,
          'newUsersToday': 0,
          'newReportsToday': 0,
        };
      }

      // We don't need to load content stats for the dashboard
      // But we'll keep the code here for reference
      /*
      try {
        await _adminService.getContentStats();
      } catch (e) {
        // Ignore content stats errors
      }
      */

      if (mounted) {
        setState(() {
          _userStats = userStats;
          _communityStats = communityStats;
          _activityStats = activityStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Error in loading stats
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Set default values even if everything fails
        setState(() {
          _userStats = {
            'communityUsers': 4,
            'newUsersThisWeek': 0,
            'pendingUsers': 0,
            'newPendingUsers': 0,
          };
          _communityStats = {
            'membersCount': 4,
            'activeUsers': 1,
            'engagementRate': 25,
          };
          _activityStats = {
            'totalReports': 0,
            'dailyActivity': List<int>.filled(7, 0),
            'newPostsToday': 0,
            'newUsersToday': 0,
            'newReportsToday': 0,
          };
          _isLoading = false;
        });
      }
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
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDetails(Map<String, dynamic> reportData) {
    Navigator.pushNamed(
      context,
      '/admin/reports',
      arguments: {'initialReport': reportData},
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _buildQuickActionButton(
                icon: Icons.add_circle_outline,
                label: 'Add Notice',
                onTap: () => Navigator.pushNamed(context, '/admin/notices/add'),
                color: const Color(0xFF00C49A),
              ),
              _buildQuickActionButton(
                icon: Icons.store_outlined,
                label: 'View Listing',
                onTap: () {
                  // Navigate to the marketplace page with the Listings tab (index 1) selected
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const AdminMarketplacePage(initialTabIndex: 1),
                    ),
                  );
                },
                color: const Color(0xFF00C49A),
              ),
              _buildQuickActionButton(
                icon: Icons.volunteer_activism,
                label: 'Add Post',
                onTap: () =>
                    Navigator.pushNamed(context, '/admin/volunteer-posts/add'),
                color: const Color(0xFF00C49A),
              ),
              _buildQuickActionButton(
                icon: Icons.report_problem_outlined,
                label: 'View Reports',
                onTap: () => Navigator.pushNamed(context, '/admin/reports'),
                color: const Color(0xFF00C49A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(
                  child: Container(
                    width: 200,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ShimmerLoading(
                  child: Container(
                    width: 150,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 8,
                      right: index == 2 ? 0 : 8,
                    ),
                    child: ShimmerLoading(
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Activity Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerLoading(
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Engagement Report
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerLoading(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Build KPI cards row at the top of the dashboard
  Widget _buildKpiCards() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/admin/users'),
              child: ImprovedKpiCard(
                title: 'Community Members',
                value: _userStats?['communityUsers']?.toString() ?? '0',
                icon: Icons.people,
                color: const Color(0xFF00C49A),
                trend: '+${_userStats?['newUsersThisWeek'] ?? 0}',
                isPositiveTrend: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/admin/reports'),
              child: ImprovedKpiCard(
                title: 'Active Reports',
                value: _activityStats?['totalReports']?.toString() ?? '0',
                icon: Icons.report_problem,
                color: const Color(0xFFF5A623),
                trend: _activityStats?['newReportsToday'] != null
                    ? '+${_activityStats?['newReportsToday']}'
                    : null,
                isPositiveTrend: false,
                tooltip: 'New reports today',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/admin/users',
                arguments: {'initialTab': 1},
              ),
              child: ImprovedKpiCard(
                title: 'Pending Users',
                value: _userStats?['pendingUsers']?.toString() ?? '0',
                icon: Icons.person_add,
                color: const Color(0xFF4A90E2),
                trend: _userStats?['newPendingUsers'] != null
                    ? '+${_userStats?['newPendingUsers']}'
                    : null,
                isPositiveTrend: false,
                tooltip: 'Users waiting for verification',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build activity chart
  Widget _buildActivityChart() {
    // Get the daily activity data from the activity stats
    final List<int> dailyActivity =
        _activityStats?['dailyActivity'] as List<int>? ??
            List<int>.filled(7, 0);

    // Calculate the maximum value for scaling
    final maxActivity = dailyActivity.isEmpty
        ? 1
        : dailyActivity.reduce((a, b) => a > b ? a : b);

    // Get the day names for the last 7 days
    final now = DateTime.now();
    final dayNames = List<String>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              // Calculate the height based on the activity value
              // Scale the height between 20 and 120 based on the activity value
              final double height = maxActivity > 0
                  ? 20 + ((dailyActivity[index] / maxActivity) * 100)
                  : 20.0;

              return Column(
                children: [
                  SizedBox(
                    width: 30,
                    height: 120 - height,
                  ),
                  Container(
                    width: 30,
                    height: height,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C49A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Center(
                      child: dailyActivity[index] > 0
                          ? Text(
                              '${dailyActivity[index]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayNames[index],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _signOut,
        ),
      ],
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadCommunityAndStats,
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _communityName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome back, Admin',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildKpiCards(),
                      const SizedBox(height: 24),
                      _buildActivityChart(),
                      const SizedBox(height: 24),
                      if (_communityStats != null &&
                          _communityStats!.containsKey('engagementComponents'))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: EngagementReportCard(
                            engagementData: {
                              'engagementRate':
                                  _communityStats!['engagementRate'],
                              'engagementComponents':
                                  _communityStats!['engagementComponents'],
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      if (_recentReports.isNotEmpty)
                        RecentReportsWidget(
                          reports: _recentReports,
                          onViewDetails: _showReportDetails,
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (_userStats != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, right: 8.0),
                                child: StatisticsCard(
                                  title: 'User Statistics',
                                  color: const Color(0xFF00C49A),
                                  icon: Icons.people,
                                  items: [
                                    StatisticItem(
                                      label: 'Community Members',
                                      value: _userStats!['communityUsers'],
                                    ),
                                    StatisticItem(
                                      label: 'New This Week',
                                      value: _userStats!['newUsersThisWeek'],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_activityStats != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 8.0, right: 16.0),
                                child: StatisticsCard(
                                  title: 'Recent Activity',
                                  color: Colors.blue,
                                  icon: Icons.timeline,
                                  items: [
                                    StatisticItem(
                                      label: 'New Posts Today',
                                      value: _activityStats!['newPostsToday'],
                                    ),
                                    StatisticItem(
                                      label: 'New Users Today',
                                      value: _activityStats!['newUsersToday'],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
