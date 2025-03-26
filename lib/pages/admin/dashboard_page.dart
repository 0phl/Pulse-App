import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/statistics_card.dart';
import './admin_drawer.dart';

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
  Map<String, dynamic>? _contentStats;
  String _communityName = '';
  bool _isLoading = true;

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

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _adminService.getUserStats(),
        _adminService.getCommunityStats(),
        _adminService.getActivityStats(),
        _adminService.getContentStats(),
      ]);

      setState(() {
        _userStats = futures[0];
        _communityStats = futures[1];
        _activityStats = futures[2];
        _contentStats = futures[3];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
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
                label: 'Add Item',
                onTap: () =>
                    Navigator.pushNamed(context, '/admin/marketplace/add'),
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
    return Column(
      children: [
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: List.generate(
                4,
                (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCommunityAndStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: const AdminDrawer(),
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
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickActions(),
                            const SizedBox(height: 24),
                            if (_userStats != null)
                              StatisticsCard(
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
                            const SizedBox(height: 16),
                            if (_communityStats != null)
                              StatisticsCard(
                                title: 'Community Statistics',
                                color: const Color(0xFF00C49A),
                                icon: Icons.location_city,
                                items: [
                                  StatisticItem(
                                    label: 'Total Posts',
                                    value: _communityStats!['totalPosts'],
                                  ),
                                  StatisticItem(
                                    label: 'Active Users',
                                    value: _communityStats!['activeUsers'],
                                  ),
                                  StatisticItem(
                                    label: 'Engagement Rate',
                                    value:
                                        '${_communityStats!['engagementRate']}%',
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (_activityStats != null)
                              StatisticsCard(
                                title: 'Recent Activity',
                                color: const Color(0xFF00C49A),
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
                                  StatisticItem(
                                    label: 'Active Conversations',
                                    value:
                                        _activityStats!['activeConversations'],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
