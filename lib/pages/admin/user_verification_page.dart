import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/firestore_user.dart';
import '../scan_qr_page.dart';
import './admin_drawer.dart';

class UserVerificationPage extends StatefulWidget {
  const UserVerificationPage({Key? key}) : super(key: key);

  @override
  State<UserVerificationPage> createState() => _UserVerificationPageState();
}

class _UserVerificationPageState extends State<UserVerificationPage> {
  final _adminService = AdminService();
  bool _isLoading = true;
  List<FirestoreUser> _pendingUsers = [];
  String _communityName = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null) {
        _communityName = community.name;
      }

      await _loadPendingUsers();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      debugPrint('Loading pending verification users...');
      final pendingUsers = await _adminService.getPendingVerificationUsers();
      debugPrint('Pending users loaded: ${pendingUsers.length} users found');

      if (pendingUsers.isNotEmpty) {
        debugPrint('Pending users:');
        for (var user in pendingUsers) {
          debugPrint('- ${user.fullName} (${user.uid}): ${user.verificationStatus}');
        }
      }

      if (mounted) {
        setState(() {
          _pendingUsers = pendingUsers;
        });
        debugPrint('State updated with pending users');
      }
    } catch (e) {
      debugPrint('ERROR loading pending users: $e');
      if (mounted) {
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
    debugPrint('Opening QR scanner...');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanQRPage(title: 'Scan Registration QR'),
      ),
    );

    if (!mounted) {
      debugPrint('Widget not mounted after QR scan, aborting');
      return;
    }

    if (result != null && result is String) {
      debugPrint('QR scan result: $result');
      try {
        // Search for user with this registration ID
        debugPrint('Searching for user with registration ID: $result');
        final user = await _adminService.getUserByRegistrationId(result);

        if (!mounted) {
          debugPrint('Widget not mounted after user lookup, aborting');
          return;
        }

        if (user != null) {
          debugPrint('User found, showing verification dialog');
          _showUserVerificationDialog(user);
        } else {
          debugPrint('No user found with this registration ID');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user found with this registration ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error scanning QR code: $e');

        if (!mounted) {
          debugPrint('Widget not mounted after error, aborting');
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      debugPrint('No valid QR scan result');
    }
  }

  Future<void> _verifyUser(FirestoreUser user, bool isApproved, {String? rejectionReason}) async {
    try {
      debugPrint('===== VERIFY USER PROCESS STARTED =====');
      debugPrint('User: ${user.fullName} (${user.uid})');
      debugPrint('Action: ${isApproved ? 'APPROVE' : 'REJECT'}');
      if (rejectionReason != null) {
        debugPrint('Rejection reason: $rejectionReason');
      }

      setState(() => _isLoading = true);

      debugPrint('Calling AdminService.updateUserVerificationStatus...');
      await _adminService.updateUserVerificationStatus(
          user.uid, isApproved ? 'verified' : 'rejected', rejectionReason: rejectionReason);
      debugPrint('AdminService.updateUserVerificationStatus completed successfully');

      // Refresh the list
      debugPrint('Refreshing pending users list...');
      await _loadPendingUsers();
      debugPrint('Pending users list refreshed');

      if (mounted) {
        debugPrint('Showing success message to user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved
                ? 'User ${user.fullName} has been approved'
                : 'User ${user.fullName} has been rejected'),
            backgroundColor: isApproved ? Colors.green : Colors.red,
          ),
        );
      }
      debugPrint('===== VERIFY USER PROCESS COMPLETED =====');
    } catch (e) {
      debugPrint('===== ERROR IN VERIFY USER PROCESS =====');
      debugPrint('Error details: $e');

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
              final TextEditingController reasonController = TextEditingController();
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
                      const SizedBox(height: 16),
                      const Text(
                        'Rejection Reason (optional):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          hintText: 'Enter reason for rejection',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The reason will be visible to the user',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
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
                        final reason = reasonController.text.trim();
                        Navigator.of(context).pop(); // Close confirmation dialog
                        Navigator.of(context).pop(); // Close verification dialog
                        _verifyUser(user, false, rejectionReason: reason.isNotEmpty ? reason : null);
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

  Widget _buildUserCard(FirestoreUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
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
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.mobile,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          final TextEditingController reasonController = TextEditingController();
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
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Rejection Reason (optional):',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: reasonController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter reason for rejection',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The reason will be visible to the user',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
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
                                    final reason = reasonController.text.trim();
                                    Navigator.of(context).pop(); // Close confirmation dialog
                                    _verifyUser(user, false, rejectionReason: reason.isNotEmpty ? reason : null);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Verification'),
        elevation: 0,
      ),
      drawer: const AdminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Pending Verification',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Users waiting for verification in $_communityName',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // User list
                  Expanded(
                    child: _pendingUsers.isEmpty
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
                            itemCount: _pendingUsers.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(_pendingUsers[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _pendingUsers.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _openQRScanner,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.qr_code_scanner),
            ),
    );
  }
}
