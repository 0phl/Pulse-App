import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import './admin_drawer.dart';
import 'dart:async';
import '../scan_qr_page.dart';
import '../../models/firestore_user.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
    with TickerProviderStateMixin {
  final _adminService = AdminService();
  final _authService = AuthService();
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCommunity();
    _loadUsers();
    _loadPendingUsers();
    _searchController.addListener(_filterUsers);

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Clear search when changing tabs
      _searchController.clear();
    }
  }

  void _filterUsers() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      if (_tabController.index == 0) {
        // Filter regular users
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
              return matchesSearch && (verificationStatus == 'rejected' || (!isActive && verificationStatus != 'pending'));
            case 'New':
              return matchesSearch && isNew;
            default:
              return matchesSearch;
          }
        }).toList();
      } else {
        // Filter pending users
        _filteredPendingUsers = _pendingUsers.where((user) {
          return user.fullName.toLowerCase().contains(searchTerm) ||
              user.email.toLowerCase().contains(searchTerm) ||
              user.mobile.toLowerCase().contains(searchTerm);
        }).toList();
      }
    });
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

      // Get all users from RTDB
      final users = await _adminService.getRTDBUsers();

      // We'll check verification status in Firestore for each user
      List<Map<String, dynamic>> verifiedUsers = [];

      for (var user in users) {
        final userId = user['uid'];
        // Check Firestore for verification status
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final verificationStatus = userData['verificationStatus'] ?? 'pending';

            // Only include verified or rejected users in the main list
            if (verificationStatus != 'pending') {
              // Update the user data with the verification status from Firestore
              user['verificationStatus'] = verificationStatus;
              user['isActive'] = verificationStatus == 'verified';
              verifiedUsers.add(user);
            }
          }
        } catch (e) {
          debugPrint('Error checking verification status for user $userId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _users = verifiedUsers;
          _filteredUsers = verifiedUsers;
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

  Future<void> _loadPendingUsers() async {
    if (!mounted) return;

    try {
      // Only set loading state if this is the initial load
      if (_isInitialLoad) {
        setState(() => _isLoading = true);
      }

      final pendingUsers = await _adminService.getPendingVerificationUsers();

      if (mounted) {
        setState(() {
          _pendingUsers = pendingUsers;
          _filteredPendingUsers = pendingUsers;
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
        title: const Text('Verify User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${user.fullName}'),
              const SizedBox(height: 8),
              Text('Email: ${user.email}'),
              const SizedBox(height: 8),
              Text('Mobile: ${user.mobile}'),
              const SizedBox(height: 8),
              Text('Address: ${user.address}'),
              const SizedBox(height: 8),
              const Text('Registration ID:'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.registrationId,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please verify this information with the user\'s ID before approving.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _verifyUser(user, false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _verifyUser(user, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _isInitialLoad = false; // This is a manual refresh
    });

    await Future.wait([
      _loadUsers(),
      _loadPendingUsers(),
    ]);
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tabController.index == 0
                          ? '${_filteredUsers.length} Members'
                          : '${_filteredPendingUsers.length} Pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search members...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
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
                          fontSize: 12,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
                      selectedColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _openQRScanner,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('Scan QR Code',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
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
    String statusText;
    Color statusColor;

    // If the user has a verification status in Firestore, use that
    // Otherwise, fall back to the isActive flag from RTDB
    if (verificationStatus == 'verified') {
      statusText = 'Active';
      statusColor = Colors.green;
    } else if (verificationStatus == 'rejected') {
      statusText = 'Rejected';
      statusColor = Colors.red;
    } else if (verificationStatus == 'pending') {
      statusText = 'Pending';
      statusColor = Colors.orange;
    } else {
      // Legacy users might not have a verification status
      statusText = isActive ? 'Active' : 'Inactive';
      statusColor = isActive ? Colors.green : Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['fullName'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isNew) ...[
                          const Icon(
                            Icons.fiber_new,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'New User',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Joined ${_formatDate(joinDate)}',
                          style: TextStyle(
                            color: Colors.grey[600],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserVerificationDialog(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.mobile,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _verifyUser(user, false),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _verifyUser(user, true),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(40, 30),
                                backgroundColor: const Color(0xFF00C49A),
                              ),
                              child: const Text('Approve'),
                            ),
                          ],
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
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).primaryColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['fullName'] ?? 'No Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailTile(
                            icon: Icons.phone,
                            title: 'Mobile',
                            value: user['mobile'] ?? 'Not provided',
                          ),
                          Divider(height: 1, color: Colors.grey[200]),
                          _buildDetailTile(
                            icon: Icons.location_on,
                            title: 'Address',
                            value: user['address'] ?? 'Not provided',
                          ),
                          Divider(height: 1, color: Colors.grey[200]),
                          _buildDetailTile(
                            icon: Icons.business,
                            title: 'Barangay',
                            value: user['barangay'] ?? 'Not provided',
                          ),
                          Divider(height: 1, color: Colors.grey[200]),
                          _buildDetailTile(
                            icon: Icons.calendar_today,
                            title: 'Joined',
                            value: _formatDate(
                                DateTime.parse(user['createdAt'].toString())),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(currentPage: 'Manage Users'),
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Pending Verification'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Users Tab
                _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _isInitialLoad ? 'Loading users...' : 'Refreshing...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(_filteredUsers[index]);
                            },
                          ),

                // Pending Verification Tab
                _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _isInitialLoad ? 'Loading pending users...' : 'Refreshing...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredPendingUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_disabled,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending verification users',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _openQRScanner,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scan QR Code'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
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
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _openQRScanner,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            )
          : null,
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
    Key? key,
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
  }) : super(key: key);

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
        color: selected
            ? Theme.of(context).primaryColor
            : Colors.grey.withOpacity(0.3),
        width: 1,
      ),
      showCheckmark: false,
    );
  }
}
