import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';

class AdminDrawer extends StatefulWidget {
  const AdminDrawer({super.key});

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> with WidgetsBindingObserver {
  final _adminService = AdminService();
  final _authService = AuthService();
  String _communityName = '';
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _profileImageUrl;
  // Key that will change when the app is resumed to force a complete rebuild
  late Key _drawerKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drawerKey = UniqueKey();
    _loadCommunity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AdminDrawer: App lifecycle state changed to $state');

    if (state == AppLifecycleState.resumed) {
      // Reload community data and profile image when app is resumed
      debugPrint('AdminDrawer: App resumed - reloading community and profile data');

      // Force a complete rebuild of the drawer with a new key
      if (mounted) {
        // Reset the profile image URL to ensure it's reloaded
        setState(() {
          _drawerKey = UniqueKey();
          _profileImageUrl = null;
        });

        _loadCommunity();
      }
    }
  }

  Future<void> _loadCommunity() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final community = await _adminService.getCurrentAdminCommunity();

      final user = _authService.currentUser;
      if (user != null) {
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (adminDoc.exists) {
            final adminData = adminDoc.data() as Map<String, dynamic>;
            _profileImageUrl = adminData['profileImageUrl'];
            debugPrint('AdminDrawer: Admin profile image loaded');
          }
        } catch (e) {
          debugPrint('AdminDrawer: Error loading admin profile: $e');
        }
      }

      if (mounted) {
        setState(() {
          if (community != null) {
            _communityName = community.name;
            debugPrint('AdminDrawer: Community loaded: ${community.name}');
          } else {
            _communityName = 'Community';
            debugPrint('AdminDrawer: No community found');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminDrawer: Error loading community: $e');
      if (mounted) {
        setState(() {
          _communityName = 'Community';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    // Debug the current route
    debugPrint('AdminDrawer: Current route: $currentRoute');

    return Stack(
      children: [
        Drawer(
          key: _drawerKey,
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
                  // Make the admin profile image clickable to navigate to profile page
                  Tooltip(
                    message: 'My Profile',
                    child: GestureDetector(
                      onTap: () => _navigateTo('/admin/profile'),
                      child: Stack(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_profileImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Color(0xFF00C49A),
                                  )
                                : null,
                          ),
                          // Small edit icon to indicate this is clickable
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C49A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateTo('/admin/profile'),
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
                          const Row(
                            children: [
                              Text(
                                'Admin Panel',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              // Small profile icon to indicate this is clickable
                              Icon(
                                Icons.person,
                                size: 12,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu items - using Expanded and a Column to push logout to bottom
            Expanded(
              child: Column(
                children: [
                  // Main menu items in a scrollable list
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
                          isActive: currentRoute == '/admin/volunteer-posts',
                          onTap: () => _navigateTo('/admin/volunteer-posts'),
                        ),
                        _buildMenuItem(
                          icon: Icons.report_outlined,
                          title: 'Reports',
                          isActive: currentRoute == '/admin/reports',
                          onTap: () => _navigateTo('/admin/reports'),
                        ),
                      ],
                    ),
                  ),

                  // Logout section at the bottom
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
          ],
        ),
          ),
        ),
        // Logout loading overlay
        if (_isLoggingOut)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Signing out...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
          color: isActive ? const Color(0xFF00C49A).withAlpha(25) : null,
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
    // Debug print
    debugPrint('AdminDrawer: Navigating to route: $route');

    // Close the drawer first
    Navigator.pop(context);

    // Then navigate to the desired route
    Navigator.pushReplacementNamed(context, route).then((_) {
      debugPrint('AdminDrawer: Navigation completed to: $route');
    }).catchError((error) {
      debugPrint('AdminDrawer: Navigation error: $error');
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 2500));

      // Navigate after the delay
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }

      // Then sign out after navigation
      await _adminService.signOut();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
}
