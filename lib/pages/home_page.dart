import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/community_notice_service.dart';
import '../services/community_service.dart';
import '../models/community_notice.dart';
import '../widgets/community_notice_card.dart';
import 'add_community_notice_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _communityService = CommunityService();
  final _noticeService = CommunityNoticeService();
  String? _currentUserCommunityId;
  bool _isAdmin = false;
  bool _isLoading = true;
  String _communityName = '';
  String _userInitial = '?';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Stream<String> _getUserInitial() {
    final database = FirebaseDatabase.instance.ref();
    final user = _auth.currentUser;

    if (user != null) {
      return database.child('users').child(user.uid).onValue.map((event) {
        if (event.snapshot.value != null) {
          final userData = event.snapshot.value as Map<dynamic, dynamic>;
          final fullName = userData['fullName'] as String? ??
              userData['username'] as String? ??
              '?';
          return fullName[0].toUpperCase();
        }
        return '?';
      });
    }
    return Stream.value('?');
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
      }
    } catch (e) {
      print('Error loading user data: $e');
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
    await _loadUserData();
  }

  void _handleNoticeAdded(String noticeId) {
    _refreshNotices();
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
        title: const Text(
          'PULSE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Navigate to notifications page
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            icon: StreamBuilder<String>(
              stream: _getUserInitial(),
              builder: (context, snapshot) {
                return CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    snapshot.data ?? '?',
                    style: const TextStyle(
                      color: Color(0xFF00C49A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFF00C49A)),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                // Navigate to login page
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotices,
        color: const Color(0xFF00C49A),
        child: StreamBuilder<List<CommunityNotice>>(
          stream: _noticeService.getNotices(_currentUserCommunityId!),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final notices = snapshot.data!;
            if (notices.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final notice = notices[index];
                return CommunityNoticeCard(
                  notice: notice,
                  isAdmin: _isAdmin,
                  onDelete: _isAdmin
                      ? () async {
                          try {
                            await _noticeService.deleteNotice(notice.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notice deleted successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error deleting notice: $e'),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
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
              backgroundColor: const Color(0xFF00C49A),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
