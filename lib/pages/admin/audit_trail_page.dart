import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';

class AdminAuditTrailPage extends StatefulWidget {
  const AdminAuditTrailPage({super.key});

  @override
  State<AdminAuditTrailPage> createState() => _AdminAuditTrailPageState();
}

class _AdminAuditTrailPageState extends State<AdminAuditTrailPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _auditLogService = AuditLogService();
  String _communityName = '';
  
  // Filtering state
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedActionType;
  bool _isLoading = false;
  String _sortOrder = 'desc'; // 'asc' or 'desc'
  
  // Pagination state
  static const int _logsPerPage = 20;
  List<QueryDocumentSnapshot> _logs = [];
  bool _hasMoreLogs = true;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadInitialLogs();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == 
          _scrollController.position.maxScrollExtent) {
        if (_hasMoreLogs && !_isLoadingMore) {
          _loadMoreLogs();
        }
      }
    });
  }

  Future<void> _loadInitialLogs() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _logs = [];
      _lastDocument = null;
      _hasMoreLogs = true;
    });

    try {
      final snapshot = await _auditLogService.getAuditLogs(
        startAfter: null,
        limit: _logsPerPage,
        actionType: _selectedActionType,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _logs = snapshot.docs;
        if (_logs.length < _logsPerPage) {
          _hasMoreLogs = false;
        }
        _lastDocument = _logs.isNotEmpty ? _logs.last : null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audit logs: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMoreLogs) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snapshot = await _auditLogService.getAuditLogs(
        startAfter: _lastDocument,
        limit: _logsPerPage,
        actionType: _selectedActionType,
        startDate: _startDate,
        endDate: _endDate,
      );

      final newLogs = snapshot.docs;
      
      setState(() {
        _logs.addAll(newLogs);
        _hasMoreLogs = newLogs.length == _logsPerPage;
        _lastDocument = newLogs.isNotEmpty ? newLogs.last : _lastDocument;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more logs: $e')),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
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
        title: const Text('Audit Trail'),
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
              selected: true,
              leading: const Icon(Icons.history),
              title: const Text('Audit Trail'),
              textColor: const Color(0xFF00C49A),
              iconColor: const Color(0xFF00C49A),
              onTap: () {
                Navigator.pop(context);
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
      body: Column(
        children: [
          // Filters section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedActionType,
                          decoration: const InputDecoration(
                            labelText: 'Action Type',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Actions'),
                            ),
                            ...AuditActionType.values.map((type) => 
                              DropdownMenuItem(
                                value: type.value,
                                child: Text(type.value.split('_').join(' ').toLowerCase()),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedActionType = value;
                              _loadInitialLogs();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          _sortOrder == 'desc' 
                            ? Icons.arrow_downward 
                            : Icons.arrow_upward,
                        ),
                        onPressed: () {
                          setState(() {
                            _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc';
                            _loadInitialLogs();
                          });
                        },
                        tooltip: 'Sort ${_sortOrder == 'desc' ? 'Newest First' : 'Oldest First'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: _startDate != null && _endDate != null
                                  ? DateTimeRange(
                                      start: _startDate!,
                                      end: _endDate!,
                                    )
                                  : null,
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked.start;
                                _endDate = picked.end;
                                _loadInitialLogs();
                              });
                            }
                          },
                          child: Text(
                            _startDate != null && _endDate != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - '
                                  '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'Select Date Range',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _selectedActionType = null;
                            _loadInitialLogs();
                          });
                        },
                        child: const Text('Clear Filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Audit logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('No audit logs found'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length + (_hasMoreLogs ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _logs.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final log = _logs[index].data() as Map<String, dynamic>;
                          final timestamp = (log['timestamp'] as Timestamp).toDate();
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              leading: _getActionIcon(log['actionType']),
                              title: Text(
                                log['actionType'].toString().split('_').join(' ').toLowerCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${timestamp.day}/${timestamp.month}/${timestamp.year} '
                                '${timestamp.hour}:${timestamp.minute}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log['isAdmin'] 
                                          ? 'Admin: ${log['userEmail']}'
                                          : 'User: ${log['userEmail']}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Resource: ${log['targetResource']}'),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Details:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(log['details'].toString()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Icon _getActionIcon(String actionType) {
    switch (actionType) {
      case 'USER_CREATED':
      case 'USER_UPDATED':
      case 'USER_DELETED':
        return const Icon(Icons.person, color: Colors.blue);
      case 'COMMUNITY_CREATED':
      case 'COMMUNITY_UPDATED':
      case 'COMMUNITY_DELETED':
        return const Icon(Icons.group, color: Colors.green);
      case 'REPORT_HANDLED':
        return const Icon(Icons.report_problem, color: Colors.orange);
      case 'SETTINGS_CHANGED':
        return const Icon(Icons.settings, color: Colors.grey);
      case 'LOGIN_ATTEMPT':
        return const Icon(Icons.login, color: Colors.purple);
      case 'PASSWORD_CHANGED':
        return const Icon(Icons.lock, color: Colors.red);
      case 'DATA_EXPORTED':
        return const Icon(Icons.download, color: Colors.teal);
      case 'VOLUNTEER_SIGNED_UP':
        return const Icon(Icons.person_add, color: Colors.green);
      case 'VOLUNTEER_CANCELLED':
        return const Icon(Icons.person_remove, color: Colors.red);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
