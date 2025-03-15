import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _auditLogService = AuditLogService();
  String _communityName = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  
  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadUsers();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total Users: ${_users.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(user['fullName'] ?? 'No Name'),
                          subtitle: Text(user['email'] ?? ''),
                          onTap: () => _viewUserDetails(user),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Log that admin is viewing user list
      await _auditLogService.logAction(
        actionType: AuditActionType.userViewed.value,
        targetResource: 'users',
        details: {
          'action': 'Viewed user list',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final users = await _adminService.getRTDBUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _viewUserDetails(Map<String, dynamic> user) async {
    try {
      // Log that admin is viewing specific user details
      await _auditLogService.logAction(
        actionType: AuditActionType.userViewed.value,
        targetResource: 'users/${user['uid']}',
        details: {
          'action': 'Viewed user details',
          'userEmail': user['email'],
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Show user details in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(user['fullName'] ?? 'User Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${user['email']}'),
                const SizedBox(height: 8),
                Text('Mobile: ${user['mobile']}'),
                const SizedBox(height: 8),
                Text('Address: ${user['address']}'),
                const SizedBox(height: 8),
                Text('Barangay: ${user['barangay']}'),
                const SizedBox(height: 8),
                Text('Joined: ${user['createdAt'].toString().split('.')[0]}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing user details: $e')),
        );
      }
    }
  }
}
