import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../models/community_notice.dart';
import '../../widgets/create_notice_sheet.dart';
import '../../widgets/notice_card.dart';
import './admin_drawer.dart';

class AdminCommunityNoticesPage extends StatefulWidget {
  const AdminCommunityNoticesPage({super.key});

  @override
  State<AdminCommunityNoticesPage> createState() =>
      _AdminCommunityNoticesPageState();
}

class _AdminCommunityNoticesPageState extends State<AdminCommunityNoticesPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _scrollController = ScrollController();

  String _communityName = '';
  bool _isLoading = true;
  List<CommunityNotice> _notices = [];
  bool _isCreatingNotice = false;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadNotices();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreNotices();
    }
  }

  Future<void> _loadMoreNotices() async {
    // TODO: Implement pagination
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

  Future<void> _createNotice() async {
    setState(() => _isCreatingNotice = true);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const CreateNoticeSheet(),
      );
      _loadNotices();
    } finally {
      if (mounted) {
        setState(() => _isCreatingNotice = false);
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _createNotice,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Share an update...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.photo_library,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNotice(CommunityNotice notice) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateNoticeSheet(notice: notice),
    );
    _loadNotices();
  }

  Future<void> _deleteNotice(String noticeId) async {
    try {
      await _adminService.deleteNotice(noticeId);
      _loadNotices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notice: $e')),
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
      drawer: const AdminDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadNotices,
                    child: _notices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.announcement_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notices yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first community notice',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            itemCount: _notices.length,
                            itemBuilder: (context, index) {
                              final notice = _notices[index];
                              return NoticeCard(
                                notice: notice,
                                onEdit: () => _editNotice(notice),
                                onDelete: () => _deleteNotice(notice.id),
                                onRefresh: _loadNotices,
                              );
                            },
                          ),
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
      final notices = await _adminService.getNotices();
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notices: $e')),
        );
        setState(() => _isLoading = false);
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
}
