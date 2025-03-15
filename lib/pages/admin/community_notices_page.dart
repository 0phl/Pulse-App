import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';
import '../../models/community_notice.dart';

class AdminCommunityNoticesPage extends StatefulWidget {
  const AdminCommunityNoticesPage({super.key});

  @override
  State<AdminCommunityNoticesPage> createState() => _AdminCommunityNoticesPageState();
}

class _AdminCommunityNoticesPageState extends State<AdminCommunityNoticesPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _auditLogService = AuditLogService();
  String _communityName = '';
  bool _isLoading = false;
  List<CommunityNotice> _notices = [];
  
  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadNotices();
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
        title: const Text('Community Notices'),
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
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/admin/users');
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
              selected: true,
              leading: const Icon(Icons.announcement),
              title: const Text('Community Notices'),
              textColor: const Color(0xFF00C49A),
              iconColor: const Color(0xFF00C49A),
              onTap: () {
                Navigator.pop(context);
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
                  child: ElevatedButton.icon(
                    onPressed: _createNotice,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Notice'),
                  ),
                ),
                Expanded(
                  child: _notices.isEmpty
                      ? const Center(child: Text('No notices yet'))
                      : ListView.builder(
                          itemCount: _notices.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final notice = _notices[index];
                            return Card(
                              child: ListTile(
                                title: Text(notice.title),
                                subtitle: Text(
                                  notice.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editNotice(notice);
                                    } else if (value == 'delete') {
                                      _deleteNotice(notice);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadNotices() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Log that admin is viewing notices
      await _auditLogService.logAction(
        actionType: AuditActionType.noticeViewed.value,
        targetResource: 'notices',
        details: {
          'action': 'Viewed community notices',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // TODO: Implement loading notices from Firestore
      setState(() {
        _notices = [
          CommunityNotice(
            id: '1',
            title: 'Sample Notice',
            content: 'This is a sample notice content.',
            createdAt: DateTime.now(),
            likes: 0,
            comments: 0,
            authorName: 'Admin',
            authorId: 'admin1',
            communityId: 'community1',
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notices: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNotice() async {
    try {
      // TODO: Implement notice creation UI and logic
      final notice = CommunityNotice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Notice',
        content: 'New notice content',
        createdAt: DateTime.now(),
        likes: 0,
        comments: 0,
        authorName: 'Admin',
        authorId: 'admin1',
        communityId: 'community1',
      );

      // Log notice creation
      await _auditLogService.logAction(
        actionType: AuditActionType.noticeCreated.value,
        targetResource: 'notices/${notice.id}',
        details: {
          'action': 'Created new notice',
          'noticeTitle': notice.title,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice created successfully')),
      );

      _loadNotices(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating notice: $e')),
      );
    }
  }

  Future<void> _editNotice(CommunityNotice notice) async {
    try {
      // TODO: Implement notice editing UI and logic

      // Log notice update
      await _auditLogService.logAction(
        actionType: AuditActionType.noticeUpdated.value,
        targetResource: 'notices/${notice.id}',
        details: {
          'action': 'Updated notice',
          'noticeTitle': notice.title,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice updated successfully')),
      );

      _loadNotices(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating notice: $e')),
      );
    }
  }

  Future<void> _deleteNotice(CommunityNotice notice) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Notice'),
          content: const Text('Are you sure you want to delete this notice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // TODO: Implement notice deletion logic

      // Log notice deletion
      await _auditLogService.logAction(
        actionType: AuditActionType.noticeDeleted.value,
        targetResource: 'notices/${notice.id}',
        details: {
          'action': 'Deleted notice',
          'noticeTitle': notice.title,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice deleted successfully')),
      );

      _loadNotices(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notice: $e')),
      );
    }
  }
}
