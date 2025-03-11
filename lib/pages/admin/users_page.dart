import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  String _communityName = '';
  
  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null && mounted) {
        setState(() => _communityName = community.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading community: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
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
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/dashboard');
              },
            ),
            ListTile(
              selected: true,
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              textColor: const Color(0xFF00C49A),
              iconColor: const Color(0xFF00C49A),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Trail'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/audit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Community Notices'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/notices');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Marketplace'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/marketplace');
              },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Volunteer Posts'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/volunteer-posts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/reports');
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
      body: const Center(
        child: Text('Manage Users Content'),
      ),
    );
  }
}
