import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../models/community_notice.dart';
import '../../widgets/create_notice_sheet.dart';
import '../../widgets/notice_card.dart';
import '../../widgets/admin_scaffold.dart';
import '../../widgets/confirmation_dialog.dart';


class AdminCommunityNoticesPage extends StatefulWidget {
  const AdminCommunityNoticesPage({super.key});

  @override
  State<AdminCommunityNoticesPage> createState() =>
      _AdminCommunityNoticesPageState();
}

class _AdminCommunityNoticesPageState extends State<AdminCommunityNoticesPage> with WidgetsBindingObserver {
  final _adminService = AdminService();
  final _scrollController = ScrollController();

  bool _isLoading = true;
  List<CommunityNotice> _notices = [];
  bool _isCreatingNotice = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCommunity();
    _loadNotices();
    _updateProfileInNotices(); // Update profile info in all notices
    _scrollController.addListener(_onScroll);
  }

  // Update profile information in all notices
  Future<void> _updateProfileInNotices() async {
    try {
      await _adminService.updateExistingNoticesWithProfileInfo();
    } catch (e) {
      debugPrint('Error updating profile in notices: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload notices when app is resumed from background
      debugPrint('App resumed - reloading notices');
      _updateProfileInNotices(); // Update profile info in all notices
      _loadAdminProfile(); // Reload admin profile
      _loadNotices();
    }
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
      await _adminService.getCurrentAdminCommunity();
      await _loadAdminProfile();
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

  Future<void> _loadAdminProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) return;

      final adminData = adminDoc.data() as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _profileImageUrl = adminData['profileImageUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
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
        onTap: _isCreatingNotice ? null : _createNotice,
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
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      )
                    : null,
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
    // Show confirmation dialog
    final shouldDelete = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Notice',
      message: 'Are you sure you want to delete this community notice? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
      icon: Icons.delete_outline,
      iconBackgroundColor: Colors.red,
    );

    // If user cancels or dismisses the dialog
    if (shouldDelete != true) return;

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
    return AdminScaffold(
      title: 'Community Notices',
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
      // Add a delay to ensure Firebase connection is stable
      // This helps when the app is resumed from background
      await Future.delayed(const Duration(milliseconds: 300));

      final notices = await _adminService.getNotices();
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Log the error for debugging
      debugPrint('Error loading notices: $e');

      if (mounted) {
        // Show a more user-friendly error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading notices. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadNotices,
            ),
          ),
        );

        // Set empty notices list to avoid null errors
        setState(() {
          _notices = [];
          _isLoading = false;
        });
      }
    }
  }


}
