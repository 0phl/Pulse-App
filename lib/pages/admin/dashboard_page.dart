import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/statistics_card.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  
  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _communityStats;
  Map<String, dynamic>? _activityStats;
  Map<String, dynamic>? _contentStats;
  String _communityName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunityAndStats();
  }

  Future<void> _loadCommunityAndStats() async {
    setState(() => _isLoading = true);
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null) {
        setState(() => _communityName = community.name);
      }
      await _loadStats();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 35,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _communityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              selected: true,
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/users');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Trail'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin/audit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Community Notices'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin/notices');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Marketplace'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin/marketplace');
              },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Volunteer Posts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin/volunteer-posts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/reports');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCommunityAndStats,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      _communityName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.count(
                          crossAxisCount: constraints.maxWidth > 600 ? 2 : 1,
                          padding: const EdgeInsets.all(16.0),
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (_userStats != null)
                              StatisticsCard(
                                title: 'User Statistics',
                                color: const Color(0xFF00C49A),
                                icon: Icons.people,
                                items: [
                                  StatisticItem(
                                    label: 'Total Users',
                                    value: _userStats!['totalUsers'],
                                  ),
                                  StatisticItem(
                                    label: 'Users in Your Community',
                                    value: _userStats!['communityUsers'],
                                  ),
                                  StatisticItem(
                                    label: 'New This Week',
                                    value: _userStats!['newUsersThisWeek'],
                                  ),
                                ],
                              ),
                            if (_activityStats != null)
                              StatisticsCard(
                                title: 'Activity',
                                color: Colors.orange,
                                icon: Icons.analytics,
                                items: [
                                  StatisticItem(
                                    label: 'Reports',
                                    value: _activityStats!['totalReports'],
                                  ),
                                  StatisticItem(
                                    label: 'Volunteer Posts',
                                    value: _activityStats!['volunteerPosts'],
                                  ),
                                  StatisticItem(
                                    label: 'Recent Logs (24h)',
                                    value: _activityStats!['recentLogs'],
                                  ),
                                  StatisticItem(
                                    label: 'Active Chats',
                                    value: _activityStats!['activeChats'],
                                  ),
                                ],
                              ),
                            if (_contentStats != null)
                              StatisticsCard(
                                title: 'Content',
                                color: Colors.purple,
                                icon: Icons.article,
                                items: [
                                  StatisticItem(
                                    label: 'Market Items',
                                    value: _contentStats!['marketItems'],
                                  ),
                                  StatisticItem(
                                    label: 'Community Notices',
                                    value: _contentStats!['communityNotices'],
                                  ),
                                  StatisticItem(
                                    label: 'Recent Posts (7d)',
                                    value: _contentStats!['recentPosts'],
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
