import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/community_notice_service.dart';
import '../services/community_service.dart';
import '../services/admin_service.dart';
import '../models/community_notice.dart';
import '../widgets/community_notice_card.dart';
import '../widgets/notifications/notification_badge.dart';
import 'add_community_notice_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  // Use a global key that can be accessed from outside
  static final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

  // Constructor without const keyword
  HomePage({Key? key}) : super(key: key ?? homeKey);

  // Static method to scroll to top that can be called from outside
  static void scrollToTop() {
    homeKey.currentState?.scrollToTop();
  }

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _communityService = CommunityService();
  final _noticeService = CommunityNoticeService();
  final _adminService = AdminService();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserCommunityId;
  bool _isAdmin = false;
  bool _isLoading = true;
  String _communityName = '';

  // Method to scroll to top with animation
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Stream<Map<String, dynamic>> _getUserData() {
    final database = FirebaseDatabase.instance.ref();
    final user = _auth.currentUser;

    if (user != null) {
      return database.child('users').child(user.uid).onValue.map((event) {
        if (event.snapshot.value != null) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          final fullName = userData['fullName'] as String? ??
              userData['username'] as String? ??
              '?';
          final initial = fullName[0].toUpperCase();
          final profileImageUrl = userData['profileImageUrl'] as String?;

          return {
            'initial': initial,
            'profileImageUrl': profileImageUrl,
          };
        }
        return {'initial': '?', 'profileImageUrl': null};
      });
    }

    return Stream.value({'initial': '?', 'profileImageUrl': null});
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final community = await _communityService.getUserCommunity(user.uid);
      if (community != null && mounted) {
        setState(() {
          _currentUserCommunityId = community.id;
          _isAdmin = community.adminId == user.uid;
          _isLoading = false;
          _communityName = community.name;
        });

        // If this is an admin, update existing notices with profile information
        if (_isAdmin) {
          // Run this in the background to avoid blocking the UI
          _adminService.updateExistingNoticesWithProfileInfo();
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to $_communityName!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isAdmin
                  ? 'Start building your community by creating the first notice!'
                  : 'No community notices yet. Stay tuned for updates from your community admin!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isAdmin)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddCommunityNoticePage(
                        onNoticeAdded: (String noticeId) {
                          _refreshNotices();
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create First Notice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'What to expect:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    Icons.notifications_active_outlined,
                    'Important community announcements',
                  ),
                  _buildInfoItem(
                    Icons.event_outlined,
                    'Upcoming events and activities',
                  ),
                  _buildInfoItem(
                    Icons.group_outlined,
                    'Community initiatives and updates',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNotices() async {
    debugPrint('HomePage: Refreshing notices');
    if (mounted) {
      setState(() => _isLoading = true);
    }

    await _loadUserData();

    if (mounted) {
      setState(() => _isLoading = false);
    }
    debugPrint('HomePage: Notices refreshed');
  }

  void _handleNoticeAdded(String noticeId) {
    _refreshNotices();
  }

  // Method to handle notice deletion with proper context management
  Future<void> _deleteNotice(String noticeId, BuildContext contextFromCaller) async {
    // Store the context locally to avoid issues with async gaps
    final BuildContext context = contextFromCaller;

    // Show a loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            ),
          ),
        ),
      );
    }

    try {
      // Delete the notice
      debugPrint('Deleting notice: $noticeId');
      await _noticeService.deleteNotice(noticeId);
      debugPrint('Notice deleted successfully');

      // Close the loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice deleted successfully'),
            backgroundColor: Color(0xFF00C49A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notice: $e');

      // Close the loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserCommunityId == null) {
      return const Scaffold(
        body: Center(child: Text('No community found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PULSE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _communityName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00C49A),
        actions: [
          NotificationBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: StreamBuilder<Map<String, dynamic>>(
              stream: _getUserData(),
              builder: (context, snapshot) {
                final userData = snapshot.data ?? {'initial': '?', 'profileImageUrl': null};
                final initial = userData['initial'] as String;
                final profileImageUrl = userData['profileImageUrl'] as String?;

                return CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 16,
                  child: profileImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          profileImageUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF00C49A),
                                  strokeWidth: 2,
                                  value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              initial,
                              style: const TextStyle(
                                color: Color(0xFF00C49A),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF00C49A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                );
              },
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Profile'),
                onTap: () {
                  // We need to add a delay because PopupMenuItem's onTap doesn't
                  // wait for the menu to close before executing the navigation
                  // We need to use a post-frame callback to avoid BuildContext issues
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      );
                    }
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Notification Settings'),
                onTap: () {
                  // We need to use a post-frame callback to avoid BuildContext issues
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pushNamed(context, '/notification-settings');
                    }
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: () async {
                  await _auth.signOut();
                  // Use a post-frame callback to avoid BuildContext issues
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                        );
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community Notices',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C49A),
                  ),
                ),
                if (_isAdmin)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCommunityNoticePage(
                            onNoticeAdded: _handleNoticeAdded,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Notice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C49A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CommunityNotice>>(
              stream: _noticeService.getNotices(_currentUserCommunityId!),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notices = snapshot.data ?? [];

                if (notices.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: _refreshNotices,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notices.length,
                    itemBuilder: (context, index) {
                      final notice = notices[index];
                      return CommunityNoticeCard(
                        key: ValueKey('notice_${notice.id}'), // Add key to help Flutter identify this widget uniquely
                        notice: notice,
                        isAdmin: _isAdmin,
                        onDelete: _isAdmin ? () {
                          debugPrint('HomePage: Delete function called for notice ${notice.id}');

                          // Use a more direct approach to delete the notice
                          // This avoids issues with the stream refreshing during deletion
                          _deleteNotice(notice.id, context);
                        } : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
