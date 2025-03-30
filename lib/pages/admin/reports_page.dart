import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import './admin_drawer.dart';
import '../../widgets/report_card.dart';
import '../../widgets/pie_chart_painter.dart';
import '../../widgets/report_detail_dialog.dart';
import '../../widgets/report_action_dialogs.dart';
import '../../widgets/reports_analytics.dart';
import '../../widgets/report_filter_chip.dart';
import '../../constants/report_styles.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _authService = AuthService();
  late TabController _tabController;
  String _communityName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _resolvedReports = [];
  String _selectedFilter = 'All';
  String _searchQuery = '';
  Map<String, int> _reportStats = {
    'total': 0,
    'pending': 0,
    'inProgress': 0,
    'resolved': 0,
    'rejected': 0,
  };
  final List<String> _tabs = ['Active Reports', 'Resolved', 'Analytics'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadCommunity(),
        _loadReports(),
        _loadReportStats(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error loading data: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00C49A),
      ),
    );
  }

  Future<void> _loadCommunity() async {
    try {
      final community = await _adminService.getCurrentAdminCommunity();
      if (community != null && mounted) {
        setState(() => _communityName = community.name);
      }
    } catch (e) {
      print('Error loading community: $e');
    }
  }

  Future<void> _loadReportStats() async {
    try {
      // In a real app, you would fetch this from your service
      setState(() {
        _reportStats = {
          'total': 42,
          'pending': 15,
          'inProgress': 8,
          'resolved': 16,
          'rejected': 3,
        };
      });
    } catch (e) {
      print('Error loading report stats: $e');
    }
  }

  Future<void> _loadReports() async {
    try {
      // TODO: Replace with actual Firestore implementation
      // This is placeholder data for demonstration
      final List<Map<String, dynamic>> allReports = [
        {
          'id': '1001',
          'type': 'Street Light Damage',
          'status': 'pending',
          'reporterName': 'John Smith',
          'reporterEmail': 'john@example.com',
          'reporterPhone': '+1234567890',
          'description':
              'Street light is not working for the past week, creating safety concerns at night.',
          'address': 'Niog, Pavillion',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 5))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 5))),
          'imageUrl': 'https://example.com/image1.jpg',
          'priority': 'medium',
          'assignedTo': '',
          'notes': '',
        },
        {
          'id': '1002',
          'type': 'Road Damage/Potholes',
          'status': 'in_progress',
          'reporterName': 'Emily Johnson',
          'reporterEmail': 'emily@example.com',
          'reporterPhone': '+1987654321',
          'description':
              'Large pothole in the middle of the road causing traffic and potential damage to vehicles.',
          'address': '123 Main St, Downtown',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 12))),
          'imageUrl': 'https://example.com/image2.jpg',
          'priority': 'high',
          'assignedTo': 'Maintenance Team',
          'notes': 'Scheduled for repair tomorrow morning.',
        },
        {
          'id': '1003',
          'type': 'Garbage Collection Problems',
          'status': 'resolved',
          'reporterName': 'Michael Brown',
          'reporterEmail': 'michael@example.com',
          'reporterPhone': '+1122334455',
          'description':
              'Garbage has not been collected for two weeks, causing sanitation issues.',
          'address': '45 Park Avenue',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 10))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
          'imageUrl': 'https://example.com/image3.jpg',
          'priority': 'medium',
          'assignedTo': 'Sanitation Department',
          'notes': 'Issue resolved. Regular collection schedule resumed.',
          'resolution':
              'Contacted sanitation department who fixed the scheduling error.',
          'resolvedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
        },
        {
          'id': '1004',
          'type': 'Flooding/Drainage Issues',
          'status': 'pending',
          'reporterName': 'Sarah Wilson',
          'reporterEmail': 'sarah@example.com',
          'reporterPhone': '+1567890123',
          'description':
              'Street floods during rain due to clogged drainage system.',
          'address': '78 Elm Street',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
          'imageUrl': 'https://example.com/image4.jpg',
          'priority': 'high',
          'assignedTo': '',
          'notes': '',
        },
        {
          'id': '1005',
          'type': 'Vandalism',
          'status': 'in_progress',
          'reporterName': 'David Lee',
          'reporterEmail': 'david@example.com',
          'reporterPhone': '+1231231234',
          'description': 'Graffiti on public building wall.',
          'address': '56 Maple Road',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 3))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
          'imageUrl': 'https://example.com/image5.jpg',
          'priority': 'low',
          'assignedTo': 'Community Cleanup Team',
          'notes': 'Scheduled for cleanup this weekend.',
        },
        {
          'id': '1006',
          'type': 'Noise Complaint',
          'status': 'rejected',
          'reporterName': 'Amy Chen',
          'reporterEmail': 'amy@example.com',
          'reporterPhone': '+1454545454',
          'description': 'Loud construction noise during night hours.',
          'address': '34 Oak Avenue',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 6))),
          'imageUrl': '',
          'priority': 'medium',
          'assignedTo': '',
          'notes': 'Rejected due to construction permit for night work.',
          'rejectionReason': 'Construction has proper permits for night work.',
        },
        {
          'id': '1007',
          'type': 'Safety Hazard',
          'status': 'resolved',
          'reporterName': 'Robert Taylor',
          'reporterEmail': 'robert@example.com',
          'reporterPhone': '+1676767676',
          'description': 'Fallen tree blocking sidewalk after storm.',
          'address': '89 Pine Street',
          'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 5))),
          'updatedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 4))),
          'imageUrl': 'https://example.com/image7.jpg',
          'priority': 'high',
          'assignedTo': 'Emergency Response Team',
          'notes': 'Tree removed, sidewalk cleared.',
          'resolution': 'Emergency team removed the tree and cleared the area.',
          'resolvedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 4))),
        },
      ];

      // Filter reports based on status
      setState(() {
        _reports = allReports
            .where((report) =>
                report['status'] == 'pending' ||
                report['status'] == 'in_progress')
            .toList();
        _resolvedReports = allReports
            .where((report) =>
                report['status'] == 'resolved' ||
                report['status'] == 'rejected')
            .toList();
      });
    } catch (e) {
      print('Error loading reports: $e');
    }
  }

  Future<void> _handleReport(String reportId, String action) async {
    try {
      // In a real app, you would use AdminService to update the report status
      setState(() {
        // Find the report in the active reports list
        final reportIndex =
            _reports.indexWhere((report) => report['id'] == reportId);

        if (reportIndex != -1) {
          final report = _reports[reportIndex];
          report['status'] = action;

          // If resolved or rejected, move to resolved reports
          if (action == 'resolved' || action == 'rejected') {
            report['updatedAt'] = Timestamp.now();
            if (action == 'resolved') {
              report['resolvedAt'] = Timestamp.now();
            }

            _resolvedReports.add(report);
            _reports.removeAt(reportIndex);
          } else {
            // Just update the status for in_progress
            _reports[reportIndex] = report;
          }
        }
      });

      _showSuccessSnackBar('Report updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error updating report: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      _showErrorSnackBar('Error signing out: $e');
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => ReportDetailDialog(
        report: report,
        onHandleReport: _handleReport,
        onAssign: _showAssignDialog,
        onAddNote: _showAddNoteDialog,
        onShowResolveDialog: _showResolveDialog,
      ),
    );
  }

  void _showAssignDialog(String reportId) async {
    final assignee = await ReportActionDialogs.showAssignDialog(context);
    if (assignee != null) {
      // In a real app, you would update the assignee
      _showSuccessSnackBar('Report assigned to $assignee');
    }
  }

  void _showResolveDialog(String reportId) async {
    final resolution = await ReportActionDialogs.showResolveDialog(context);
    if (resolution != null) {
      _handleReport(reportId, 'resolved');
    }
  }

  void _showRejectDialog(String reportId) async {
    final reason = await ReportActionDialogs.showRejectDialog(context);
    if (reason != null) {
      _handleReport(reportId, 'rejected');
    }
  }

  void _showAddNoteDialog(String reportId) async {
    final note = await ReportActionDialogs.showAddNoteDialog(context);
    if (note != null) {
      // In a real app, you would update the note
      _showSuccessSnackBar('Note added successfully');
    }
  }

  Widget _buildStatusChart() {
    return SizedBox(
      height: 200,
      child: PieChart(
        values: [
          _reportStats['pending'] ?? 0,
          _reportStats['inProgress'] ?? 0,
          _reportStats['resolved'] ?? 0,
          _reportStats['rejected'] ?? 0,
        ],
        colors: [
          Colors.orange,
          Colors.blue,
          Colors.green,
          Colors.red,
        ],
        labels: ['Pending', 'In Progress', 'Resolved', 'Rejected'],
      ),
    );
  }

  Widget _buildTypeChart() {
    // Create a sample type distribution
    final Map<String, int> typeDistribution = {
      'Street Light Damage': 12,
      'Road Damage/Potholes': 10,
      'Garbage Collection Problems': 7,
      'Flooding/Drainage Issues': 5,
      'Vandalism': 4,
      'Noise Complaint': 3,
      'Safety Hazard': 1,
    };

    return ReportTypeDistribution(typeDistribution: typeDistribution);
  }

  Widget _buildTrendChart() {
    // Sample data for weekly trend
    final List<int> weeklyData = [5, 7, 3, 8, 10, 6, 3];

    return ReportTrendChart(weeklyData: weeklyData);
  }

  Widget _buildAnalyticItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ReportAnalyticItem(
      title: title,
      value: value,
      icon: icon,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveReportsTab(),
                      _buildResolvedReportsTab(),
                      _buildAnalyticsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reports - $_communityName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: _tabs
                .map((tab) => Tab(
                      text: tab,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveReportsTab() {
    return Column(
      children: [
        // Search and filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      // TODO: Implement search filtering
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ReportFilterChip(
                label: 'All',
                isSelected: _selectedFilter == 'All',
                onSelected: (selected) {
                  setState(() => _selectedFilter = 'All');
                },
              ),
              ReportFilterChip(
                label: 'Pending',
                isSelected: _selectedFilter == 'Pending',
                onSelected: (selected) {
                  setState(() => _selectedFilter = 'Pending');
                },
              ),
              ReportFilterChip(
                label: 'In Progress',
                isSelected: _selectedFilter == 'In Progress',
                onSelected: (selected) {
                  setState(() => _selectedFilter = 'In Progress');
                },
              ),
              ReportFilterChip(
                label: 'High Priority',
                isSelected: _selectedFilter == 'High Priority',
                onSelected: (selected) {
                  setState(() => _selectedFilter = 'High Priority');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ReportStyles.cardBorderRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${_reportStats['pending'] ?? 0}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ReportStyles.statusColors['pending'],
                          ),
                        ),
                        const Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${_reportStats['inProgress'] ?? 0}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ReportStyles.statusColors['in_progress'],
                          ),
                        ),
                        const Text(
                          'In Progress',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reports list
        Expanded(
          child: _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active reports',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return ReportCard(
                      report: report,
                      onViewDetails: (_) => _showReportDetails(report),
                      onHandleReport: _handleReport,
                      onAssign: _showAssignDialog,
                      onShowResolveDialog: _showResolveDialog,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResolvedReportsTab() {
    return Column(
      children: [
        // Stats cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${_reportStats['resolved'] ?? 0}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ReportStyles.statusColors['resolved'],
                          ),
                        ),
                        const Text(
                          'Resolved Reports',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${((_reportStats['resolved'] ?? 0) / (_reportStats['total'] == 0 ? 1 : _reportStats['total'] ?? 1) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C49A),
                          ),
                        ),
                        const Text(
                          'Resolution Rate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Resolved reports list
        Expanded(
          child: _resolvedReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No resolved reports',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _resolvedReports.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final report = _resolvedReports[index];
                    return ReportCard(
                      report: report,
                      onViewDetails: (_) => _showReportDetails(report),
                      onHandleReport: _handleReport,
                      onAssign: _showAssignDialog,
                      onShowResolveDialog: _showResolveDialog,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          ReportAnalyticsCard(
            title: 'Reports Summary',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnalyticItem(
                    title: 'Total Reports',
                    value: '${_reportStats['total'] ?? 0}',
                    icon: Icons.assessment,
                            color: ReportStyles.primaryColor,
                  ),
                  _buildAnalyticItem(
                    title: 'Avg. Resolution Time',
                    value: '2.3 days',
                    icon: Icons.timer,
                    color: Colors.blue,
                  ),
                  _buildAnalyticItem(
                    title: 'Resolution Rate',
                    value:
                        '${((_reportStats['resolved'] ?? 0) / (_reportStats['total'] == 0 ? 1 : _reportStats['total'] ?? 1) * 100).toStringAsFixed(1)}%',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Reports by status chart
          ReportAnalyticsCard(
            title: 'Reports by Status',
            children: [
              _buildStatusChart(),
            ],
          ),

          const SizedBox(height: 24),

          // Reports by type chart
          ReportAnalyticsCard(
            title: 'Reports by Type',
            children: [
              _buildTypeChart(),
            ],
          ),

          const SizedBox(height: 24),

          // Reports trend chart
          ReportAnalyticsCard(
            title: 'Weekly Reports Trend',
            children: [
              _buildTrendChart(),
            ],
          ),

          const SizedBox(height: 24),

          // Report priority distribution
          ReportAnalyticsCard(
            title: 'Priority Distribution',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPriorityIndicator('High', 15, Colors.red),
                    _buildPriorityIndicator('Medium', 20, Colors.orange),
                    _buildPriorityIndicator('Low', 7, Colors.green),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
