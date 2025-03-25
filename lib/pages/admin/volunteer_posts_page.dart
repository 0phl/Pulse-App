import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../models/volunteer_post.dart';

class AdminVolunteerPostsPage extends StatefulWidget {
  const AdminVolunteerPostsPage({super.key});

  @override
  State<AdminVolunteerPostsPage> createState() =>
      _AdminVolunteerPostsPageState();
}

class _AdminVolunteerPostsPageState extends State<AdminVolunteerPostsPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  String _communityName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _volunteerPosts = [];

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadVolunteerPosts();
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
        title: const Text('Volunteer Posts'),
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
              selected: true,
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Volunteer Posts'),
              textColor: const Color(0xFF00C49A),
              iconColor: const Color(0xFF00C49A),
              onTap: () {
                Navigator.pop(context);
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
                    'Total Posts: ${_volunteerPosts.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _volunteerPosts.isEmpty
                      ? const Center(child: Text('No volunteer posts'))
                      : ListView.builder(
                          itemCount: _volunteerPosts.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final post = _volunteerPosts[index];
                            return Card(
                              child: ListTile(
                                title: Text(post['title']),
                                subtitle: Text(
                                  post['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showPostOptions(post),
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

  Future<void> _loadVolunteerPosts() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // TODO: Implement loading volunteer posts from Firestore
      setState(() {
        _volunteerPosts = [
          {
            'id': '1',
            'title': 'Sample Volunteer Post',
            'description': 'This is a sample volunteer post.',
            'userId': 'user1',
            'userName': 'Sample User',
            'location': 'Sample Location',
            'spotLimit': 10,
            'spotsLeft': 10,
            'communityId': 'community1',
            'date': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
            'imageUrl': 'https://example.com/image.jpg',
            'organizerName': 'Sample User'
          },
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading volunteer posts: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPostOptions(Map<String, dynamic> post) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _viewPostDetails(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Remove Post'),
              onTap: () {
                Navigator.pop(context);
                _removePost(post['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewPostDetails(Map<String, dynamic> post) async {
    try {
      // Show post details dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(post['title']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(post['imageUrl']),
                const SizedBox(height: 16),
                Text('Description: ${post['description']}'),
                const SizedBox(height: 8),
                Text('Location: ${post['location']}'),
                const SizedBox(height: 8),
                Text('Date: ${post['date']}'),
                const SizedBox(height: 8),
                Text('Organizer: ${post['organizerName']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing post details: $e')),
        );
      }
    }
  }

  Future<void> _removePost(String postId) async {
    try {
      await _adminService.removeVolunteerPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post removed successfully')),
        );
        _loadVolunteerPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing post: $e')),
        );
      }
    }
  }
}
