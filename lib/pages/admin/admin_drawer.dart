import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';

class AdminDrawer extends StatefulWidget {
  final String currentPage;

  const AdminDrawer({Key? key, this.currentPage = ''}) : super(key: key);

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  final _adminService = AdminService();
  String _communityName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null && mounted) {
        setState(() {
          _communityName = community.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading community: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current route to determine which menu item is active
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    // Debug the current route
    print('Current route: $currentRoute');

    return Drawer(
      elevation: 1,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF00C49A),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 24,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading ? 'Loading...' : _communityName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    isActive: currentRoute == '/admin/dashboard',
                    onTap: () => _navigateTo('/admin/dashboard'),
                  ),
                  _buildMenuItem(
                    icon: Icons.people_outline,
                    title: 'Manage Users',
                    isActive: currentRoute == '/admin/users',
                    onTap: () => _navigateTo('/admin/users'),
                  ),
                  _buildMenuItem(
                    icon: Icons.announcement_outlined,
                    title: 'Community Notices',
                    isActive: currentRoute == '/admin/notices',
                    onTap: () => _navigateTo('/admin/notices'),
                  ),
                  _buildMenuItem(
                    icon: Icons.store_outlined,
                    title: 'Marketplace',
                    isActive: currentRoute == '/admin/marketplace',
                    onTap: () => _navigateTo('/admin/marketplace'),
                  ),
                  _buildMenuItem(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Volunteer Posts',
                    // Fix: Only highlight if we're actually on the volunteer posts page
                    isActive: currentRoute == '/admin/volunteer-posts',
                    onTap: () => _navigateTo('/admin/volunteer-posts'),
                  ),
                  _buildMenuItem(
                    icon: Icons.report_outlined,
                    title: 'Reports',
                    isActive: currentRoute == '/admin/reports',
                    onTap: () => _navigateTo('/admin/reports'),
                  ),
                  _buildMenuItem(
                    icon: Icons.verified_user_outlined,
                    title: 'User Verification',
                    isActive: currentRoute == '/admin/user-verification',
                    onTap: () => _navigateTo('/admin/user-verification'),
                  ),
                ],
              ),
            ),

            // Divider and logout
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: _logout,
              showTrailing: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    bool isActive = false,
    required VoidCallback onTap,
    bool showTrailing = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00C49A).withOpacity(0.1) : null,
          border: isActive
              ? const Border(
                  left: BorderSide(
                    color: Color(0xFF00C49A),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF00C49A) : Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? const Color(0xFF00C49A) : Colors.grey[800],
                ),
              ),
            ),
            if (showTrailing)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String route) {
    // Close the drawer first
    Navigator.pop(context);

    // Then navigate to the desired route
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
}
