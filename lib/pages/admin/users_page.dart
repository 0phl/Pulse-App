import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import './admin_drawer.dart';
import 'dart:async';
import '../scan_qr_page.dart';
import '../../models/firestore_user.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with TickerProviderStateMixin {
  final _adminService = AdminService();
  final _searchController = TextEditingController();
  late TabController _tabController;
  late AnimationController _controller;

  String _communityName = '';
  bool _isLoading = true;
  bool _isInitialLoad = true; // Flag to track initial loading state
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<FirestoreUser> _pendingUsers = [];
  List<FirestoreUser> _filteredPendingUsers = [];
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Active', 'Inactive', 'New'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Add listener for search text changes
    _searchController.addListener(_filterUsers);

    // Load initial data
    debugPrint('UsersPage: initState called');
    _loadCommunity();
    _loadUsers();
    _loadPendingUsers().then((_) {
      // Force a rebuild of the filtered list after loading pending users
      if (mounted) {
        debugPrint('Forcing filter update after loading pending users');
        _filterUsers();
      }
    });

    // Start the animation
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize tab controller if not already initialized
    if (!_isTabControllerInitialized) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final initialTab = arguments?['initialTab'] as int? ?? 0;

      _tabController =
          TabController(length: 2, vsync: this, initialIndex: initialTab);
      _tabController.addListener(_handleTabChange);
      _isTabControllerInitialized = true;
    }
  }

  bool _isTabControllerInitialized = false;

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // This will trigger for both tap and slide changes
    debugPrint('Tab changed to index: ${_tabController.index}');

    if (mounted) {
      setState(() {
        // Clear search when changing tabs
        _searchController.clear();

        // Refresh data based on the new tab
        _isLoading = true;
      });

      // Load data outside of setState to avoid rebuilding too early
      if (_tabController.index == 0) {
        debugPrint('Loading All Users tab data');
        _loadUsers().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      } else {
        debugPrint('Loading Pending Verification tab data');
        _loadPendingUsers().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              // Force a rebuild of the filtered list
              _filterUsers();
            });
          }
        });
      }
    }
  }

  void _filterUsers() {
    debugPrint('_filterUsers called with search text: "${_searchController.text}"');
    debugPrint('Current tab index: ${_tabController.index}');

    setState(() {
      if (_tabController.index == 0) {
        _applyCurrentFilter();
      } else {
        // Filter pending users
        final searchTerm = _searchController.text.toLowerCase();
        debugPrint('Filtering ${_pendingUsers.length} pending users with search term: "$searchTerm"');

        // Always show all pending users if search is empty
        if (searchTerm.isEmpty) {
          _filteredPendingUsers = List.from(_pendingUsers);
          debugPrint('Search term empty, showing all ${_filteredPendingUsers.length} pending users');
        } else {
          _filteredPendingUsers = _pendingUsers.where((user) {
            return user.fullName.toLowerCase().contains(searchTerm) ||
                user.email.toLowerCase().contains(searchTerm) ||
                user.mobile.toLowerCase().contains(searchTerm);
          }).toList();
          debugPrint('After filtering, showing ${_filteredPendingUsers.length} pending users');
        }
      }
    });

    // Force update the UI to show pending users
    if (_tabController.index == 1 && mounted) {
      setState(() {});
    }
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

  Future<void> _loadUsers() async {
    if (!mounted) return;

    try {
      // Only set loading state if this is the initial load
      if (_isInitialLoad) {
        setState(() => _isLoading = true);
      }

      final users = await _adminService.getRTDBUsers();

      if (mounted) {
        setState(() {
          _users = users;
          // Apply current filter instead of showing all users
          _applyCurrentFilter();
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyCurrentFilter() {
    final searchTerm = _searchController.text.toLowerCase();
    _filteredUsers = _users.where((user) {
      final matchesSearch =
          user['fullName'].toString().toLowerCase().contains(searchTerm) ||
              user['email'].toString().toLowerCase().contains(searchTerm) ||
              user['mobile'].toString().toLowerCase().contains(searchTerm);

      if (_selectedFilter == 'All') return matchesSearch;

      final verificationStatus = user['verificationStatus'] ?? 'pending';
      final isActive = verificationStatus == 'verified';
      final joinDate = DateTime.parse(user['createdAt'].toString());
      final isNew = DateTime.now().difference(joinDate).inDays <= 7;

      switch (_selectedFilter) {
        case 'Active':
          return matchesSearch && isActive;
        case 'Inactive':
          return matchesSearch &&
              (verificationStatus == 'rejected' ||
                  (!isActive && verificationStatus != 'pending'));
        case 'New':
          return matchesSearch && isNew;
        default:
          return matchesSearch;
      }
    }).toList();
  }

  Future<void> _loadPendingUsers() async {
    if (!mounted) return;

    try {
      // Only set loading state if this is the initial load
      if (_isInitialLoad) {
        setState(() => _isLoading = true);
      }

      debugPrint('Loading pending verification users...');
      final pendingUsers = await _adminService.getPendingVerificationUsers();
      debugPrint('Found ${pendingUsers.length} pending users');

      // Log each pending user for debugging
      for (var user in pendingUsers) {
        debugPrint('Pending user: ${user.fullName} (${user.uid})');
      }

      if (mounted) {
        setState(() {
          _pendingUsers = pendingUsers;
          _filteredPendingUsers = pendingUsers;
          _isLoading = false;
          _isInitialLoad = false;
          debugPrint('Updated state with ${_pendingUsers.length} pending users');
          debugPrint('Updated filtered list with ${_filteredPendingUsers.length} pending users');
        });
      }
    } catch (e) {
      debugPrint('Error loading pending users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pending users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanQRPage(title: 'Scan Registration QR'),
      ),
    );

    if (result != null && result is String && mounted) {
      try {
        // Search for user with this registration ID
        final user = await _adminService.getUserByRegistrationId(result);

        if (!mounted) return; // Check if widget is still mounted

        if (user != null) {
          _showUserVerificationDialog(user);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user found with this registration ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return; // Check if widget is still mounted

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyUser(FirestoreUser user, bool isApproved) async {
    try {
      setState(() => _isLoading = true);

      await _adminService.updateUserVerificationStatus(
          user.uid, isApproved ? 'verified' : 'rejected');

      // Refresh the list
      await _loadPendingUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved
                ? 'User ${user.fullName} has been approved'
                : 'User ${user.fullName} has been rejected'),
            backgroundColor: isApproved ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUserVerificationDialog(FirestoreUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: const Row(
          children: [
            Icon(
              Icons.verified_user,
              color: Color(0xFF00C49A),
              size: 24,
            ),
            SizedBox(width: 8),
            Text('Verify User'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVerificationField('Name', user.fullName),
                const SizedBox(height: 12),
                _buildVerificationField('Email', user.email),
                const SizedBox(height: 12),
                _buildVerificationField('Mobile', user.mobile),
                const SizedBox(height: 12),
                _buildVerificationField('Address', user.address),
                const SizedBox(height: 16),
                const Text('Registration ID:'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    user.registrationId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please verify this information with the user\'s ID before approving.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  // Show confirmation dialog before rejecting
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text('Confirm Rejection'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you sure you want to reject ${user.fullName}?',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This user will not be able to access community features until approved.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close confirmation dialog
                            Navigator.of(context).pop(); // Close verification dialog
                            _verifyUser(user, false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Confirm Rejection'),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  // Show confirmation dialog before approving
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF00C49A),
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text('Confirm Approval'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you sure you want to approve ${user.fullName}?',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This user will be granted access to all community features.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close confirmation dialog
                            Navigator.of(context).pop(); // Close verification dialog
                            _verifyUser(user, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C49A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Confirm Approval'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _refreshData() async {
    debugPrint('Manual refresh triggered on tab ${_tabController.index}');
    setState(() {
      _isLoading = true;
      _isInitialLoad = false; // This is a manual refresh
    });

    if (_tabController.index == 0) {
      await _loadUsers();
      // Apply filter after loading
      _applyCurrentFilter();
    } else {
      await _loadPendingUsers();
      // Force a rebuild of the filtered list
      _filterUsers();
    }

    // Update UI to show loading is complete
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(currentPage: 'Manage Users'),
      appBar: AppBar(
        title: const Text(
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Pending Verification'),
          ],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white.withOpacity(0.7),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Column(
          key: ValueKey<int>(_tabController.index),
          children: [
            _buildSearchSection(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // All Users Tab
                  _buildTabContent(
                    isLoading: _isLoading,
                    isEmpty: _filteredUsers.isEmpty,
                    onRefresh: _refreshData,
                    emptyWidget: _buildEmptyState(
                      icon: Icons.people_outline,
                      message: 'No users found',
                      subMessage: 'Try adjusting your search or filters',
                    ),
                    contentWidget: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(_filteredUsers[index]);
                      },
                    ),
                  ),

                  // Pending Verification Tab
                  _buildTabContent(
                    isLoading: _isLoading,
                    isEmpty: _filteredPendingUsers.isEmpty,
                    onRefresh: _refreshData,
                    emptyWidget: Stack(
                      children: [
                        ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.2,
                            ),
                            _buildEmptyState(
                              icon: Icons.person_add_outlined,
                              message: 'No pending verification users',
                              subMessage: 'Scan a QR code to verify a new user',
                              button: ElevatedButton.icon(
                                onPressed: _openQRScanner,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan QR Code'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C49A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    contentWidget: _pendingUsers.isEmpty && !_isLoading
                      ? _buildEmptyState(
                          icon: Icons.person_add_outlined,
                          message: 'No pending verification users',
                          subMessage: 'Scan a QR code to verify a new user',
                          button: ElevatedButton.icon(
                            onPressed: _openQRScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C49A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: _filteredPendingUsers.length,
                          itemBuilder: (context, index) {
                            return _buildPendingUserCard(
                                _filteredPendingUsers[index]);
                          },
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _openQRScanner,
              backgroundColor: const Color(0xFF00C49A),
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  Widget _buildTabContent({
    required bool isLoading,
    required bool isEmpty,
    required Future<void> Function() onRefresh,
    required Widget emptyWidget,
    required Widget contentWidget,
  }) {
    return isLoading
        ? _buildLoadingIndicator()
        : RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFF00C49A),
            child: isEmpty ? emptyWidget : contentWidget,
          );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF00C49A).withOpacity(0.8),
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isInitialLoad ? 'Loading users...' : 'Refreshing...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF00C49A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _communityName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabController.index == 0
                          ? Icons.people
                          : Icons.pending_outlined,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tabController.index == 0
                          ? '${_filteredUsers.length} Members'
                          : '${_filteredPendingUsers.length} Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child:
                          Icon(Icons.close, size: 20, color: Colors.grey[400]),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_tabController.index == 0)
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : Colors.black.withOpacity(0.7),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _filterUsers();
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF00C49A),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF00C49A)
                              : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subMessage,
    Widget? button,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              subMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (button != null) ...[
            const SizedBox(height: 24),
            button,
          ],
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['isActive'] ?? false;
    final verificationStatus = user['verificationStatus'] ?? 'pending';
    final joinDate = DateTime.parse(user['createdAt'].toString());
    final isNew = DateTime.now().difference(joinDate).inDays <= 7;

    // Determine status display
    bool isActiveStatus = verificationStatus == 'verified' ||
        (verificationStatus != 'pending' &&
            verificationStatus != 'rejected' &&
            isActive);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _viewUserDetails(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C49A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF00C49A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // User information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name and NEW badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['fullName'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      user['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Status and joined date
                    Row(
                      children: [
                        // Status indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActiveStatus
                                ? Colors.green[400]
                                : verificationStatus == 'rejected'
                                    ? Colors.red[400]
                                    : Colors.orange[400],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActiveStatus
                              ? 'Active'
                              : verificationStatus == 'rejected'
                                  ? 'Rejected'
                                  : 'Pending',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(joinDate),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingUserCard(FirestoreUser user) {
    final isNew = DateTime.now().difference(user.createdAt).inDays <= 7;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _showUserVerificationDialog(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C49A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF00C49A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange[400],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pending Verification',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.phone_outlined,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.mobile,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // Show confirmation dialog before rejecting
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red[700],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text('Confirm Rejection'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Are you sure you want to reject ${user.fullName}?',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This user will not be able to access community features until approved.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // Close confirmation dialog
                                _verifyUser(user, false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Confirm Rejection'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Show confirmation dialog before approving
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF00C49A),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text('Confirm Approval'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Are you sure you want to approve ${user.fullName}?',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This user will be granted access to all community features.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // Close confirmation dialog
                                _verifyUser(user, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C49A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Confirm Approval'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C49A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }

  Future<void> _viewUserDetails(Map<String, dynamic> user) async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // User details content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildUserDetailsList(user),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing user details: $e')),
        );
      }
    }
  }

  Widget _buildUserDetailsList(Map<String, dynamic> user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile section
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF00C49A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF00C49A),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['fullName'] ?? 'No Name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Details section
        _buildDetailItem(
          icon: Icons.phone_outlined,
          label: 'Mobile',
          value: user['mobile'] ?? 'Not provided',
        ),
        const Divider(height: 1),
        _buildDetailItem(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: user['address'] ?? 'Not provided',
        ),
        const Divider(height: 1),
        _buildDetailItem(
          icon: Icons.business_outlined,
          label: 'Barangay',
          value: user['barangay'] ?? 'Not provided',
        ),
        const Divider(height: 1),
        _buildDetailItem(
          icon: Icons.calendar_today_outlined,
          label: 'Joined',
          value: _formatDate(DateTime.parse(user['createdAt'].toString())),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF00C49A),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for filter chips
class FilterChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final Function(bool) onSelected;
  final Color backgroundColor;
  final Color selectedColor;
  final EdgeInsets padding;
  final EdgeInsets labelPadding;
  final VisualDensity visualDensity;
  final MaterialTapTargetSize materialTapTargetSize;
  final OutlinedBorder shape;

  const FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.backgroundColor,
    required this.selectedColor,
    required this.padding,
    required this.labelPadding,
    required this.visualDensity,
    required this.materialTapTargetSize,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return RawChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
      padding: padding,
      labelPadding: labelPadding,
      visualDensity: visualDensity,
      materialTapTargetSize: materialTapTargetSize,
      shape: shape,
      side: BorderSide(
        color:
            selected ? const Color(0xFF00C49A) : Colors.grey.withOpacity(0.3),
        width: 1,
      ),
      showCheckmark: false,
    );
  }
}
