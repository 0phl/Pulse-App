import 'package:flutter/material.dart';
import '../../models/report.dart';
import '../../services/admin_service.dart';
// Auth service import removed as it's not used
import './admin_drawer.dart';
import '../../widgets/report_card.dart';
import '../../widgets/pie_chart_painter.dart';
import '../../widgets/report_detail_dialog.dart';
import '../../widgets/report_action_dialogs.dart';
import '../../widgets/reports_analytics.dart';
import '../../widgets/report_filter_chip.dart';
import '../../constants/report_styles.dart';

class ActiveReportsTab extends StatefulWidget {
  final AdminService adminService;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Map<String, dynamic> reportStats;
  final Function(Map<String, dynamic>) onShowReportDetails;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String) onShowRejectDialog;

  const ActiveReportsTab({
    super.key,
    required this.adminService,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.reportStats,
    required this.onShowReportDetails,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    required this.onShowRejectDialog,
  });

  @override
  State<ActiveReportsTab> createState() => _ActiveReportsTabState();
}

class _ActiveReportsTabState extends State<ActiveReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshData() async {
    // This will trigger a refresh of the report stats
    try {
      await widget.adminService.getReportStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: StreamBuilder<List<Report>>(
        stream: widget.adminService.getReports(
          status: widget.selectedFilter == 'All' ? null : widget.selectedFilter.toLowerCase()
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeReports = snapshot.data!.where((report) =>
            report.status.value == 'pending' || report.status.value == 'in_progress'
          ).toList();

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ReportFilterChip(
                    label: 'All',
                    isSelected: widget.selectedFilter == 'All',
                    onSelected: (selected) => widget.onFilterChanged('All'),
                  ),
                  ReportFilterChip(
                    label: 'Pending',
                    isSelected: widget.selectedFilter == 'pending',
                    onSelected: (selected) => widget.onFilterChanged('pending'),
                  ),
                  ReportFilterChip(
                    label: 'In Progress',
                    isSelected: widget.selectedFilter == 'in_progress',
                    onSelected: (selected) => widget.onFilterChanged('in_progress'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${widget.reportStats['statusCounts']?['pending'] ?? 0}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ReportStyles.statusColors['pending'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${widget.reportStats['statusCounts']?['in_progress'] ?? 0}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ReportStyles.statusColors['in_progress'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'In Progress',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: activeReports.isEmpty
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
                      itemCount: activeReports.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final report = activeReports[index];
                        return ReportCard(
                          report: report.toMap(),
                          onViewDetails: (_) => widget.onShowReportDetails(report.toMap()),
                          onHandleReport: widget.onHandleReport,
                          onShowResolveDialog: widget.onShowResolveDialog,
                          onShowRejectDialog: widget.onShowRejectDialog,
                        );
                      },
                    ),
            ),
          ],
        );
          },
        ),
      );
  }
}

class ResolvedReportsTab extends StatefulWidget {
  final AdminService adminService;
  final Map<String, dynamic> reportStats;
  final Function(Map<String, dynamic>) onShowReportDetails;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String)? onShowRejectDialog;

  const ResolvedReportsTab({
    super.key,
    required this.adminService,
    required this.reportStats,
    required this.onShowReportDetails,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    this.onShowRejectDialog,
  });

  @override
  State<ResolvedReportsTab> createState() => _ResolvedReportsTabState();
}

class _ResolvedReportsTabState extends State<ResolvedReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshData() async {
    // This will trigger a refresh of the report stats
    try {
      await widget.adminService.getReportStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: StreamBuilder<List<Report>>(
        stream: widget.adminService.getReports(status: 'resolved'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final resolvedReports = snapshot.data!.where((report) =>
            report.status.value == 'resolved'
          ).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.reportStats['statusCounts']?['resolved'] ?? 0}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ReportStyles.statusColors['resolved'],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Resolved',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${((widget.reportStats['statusCounts']?['resolved'] ?? 0) / (widget.reportStats['statusCounts']?['total'] == 0 ? 1 : widget.reportStats['statusCounts']?['total'] ?? 1) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00C49A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Resolution Rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
            Expanded(
              child: resolvedReports.isEmpty
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
                      itemCount: resolvedReports.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final report = resolvedReports[index];
                        return ReportCard(
                          report: report.toMap(),
                          onViewDetails: (_) => widget.onShowReportDetails(report.toMap()),
                          onHandleReport: widget.onHandleReport,
                          onShowResolveDialog: widget.onShowResolveDialog,
                          onShowRejectDialog: widget.onShowRejectDialog,
                        );
                      },
                    ),
            ),
          ],
        );
      },
      ),
    );
  }
}

class AnalyticsTab extends StatefulWidget {
  final Map<String, dynamic> reportStats;

  const AnalyticsTab({
    super.key,
    required this.reportStats,
  });

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class RejectedReportsTab extends StatefulWidget {
  final AdminService adminService;
  final Map<String, dynamic> reportStats;
  final Function(Map<String, dynamic>) onShowReportDetails;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String)? onShowRejectDialog;

  const RejectedReportsTab({
    super.key,
    required this.adminService,
    required this.reportStats,
    required this.onShowReportDetails,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    this.onShowRejectDialog,
  });

  @override
  State<RejectedReportsTab> createState() => _RejectedReportsTabState();
}

class _RejectedReportsTabState extends State<RejectedReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refreshData() async {
    // This will trigger a refresh of the report stats
    try {
      await widget.adminService.getReportStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: StreamBuilder<List<Report>>(
        stream: widget.adminService.getReports(status: 'rejected'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rejectedReports = snapshot.data!.where((report) =>
            report.status.value == 'rejected'
          ).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.reportStats['statusCounts']?['rejected'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ReportStyles.statusColors['rejected'],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Rejected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${((widget.reportStats['statusCounts']?['rejected'] ?? 0) / (widget.reportStats['statusCounts']?['total'] == 0 ? 1 : widget.reportStats['statusCounts']?['total'] ?? 1) * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Rejection Rate',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
              Expanded(
                child: rejectedReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rejected reports',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: rejectedReports.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final report = rejectedReports[index];
                          return ReportCard(
                            report: report.toMap(),
                            onViewDetails: (_) => widget.onShowReportDetails(report.toMap()),
                            onHandleReport: widget.onHandleReport,
                            onShowResolveDialog: widget.onShowResolveDialog,
                            onShowRejectDialog: widget.onShowRejectDialog,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsTabState extends State<AnalyticsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic> get statusCounts {
    final data = widget.reportStats['statusCounts'] as Map<String, dynamic>?;
    return data ?? {'total': 0, 'pending': 0, 'in_progress': 0, 'resolved': 0, 'rejected': 0};
  }

  Map<String, dynamic> get typeDistribution {
    final data = widget.reportStats['typeDistribution'] as Map<String, dynamic>?;
    return data ?? {};
  }

  List<dynamic> get weeklyData {
    final data = widget.reportStats['weeklyData'] as List<dynamic>?;
    final result = data ?? [0, 0, 0, 0, 0, 0, 0];
    print('Weekly Data: $result');
    return result;
  }

  String get avgResolutionTime =>
      widget.reportStats['avgResolutionTime'] as String? ?? '0.0';

  // Calculate percentage for pie chart labels
  String _getPercentage(int value, int total) {
    if (total == 0) return '0.0';
    return ((value / total) * 100).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportAnalyticsCard(
            title: 'Reports Summary',
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ReportAnalyticItem(
                          title: 'Total Reports',
                          value: '${statusCounts['total'] ?? 0}',
                          icon: Icons.assessment,
                          color: ReportStyles.primaryColor,
                          isTopRow: true,
                        ),
                        ReportAnalyticItem(
                          title: 'Avg. Resolution Time',
                          value: '$avgResolutionTime days',
                          icon: Icons.timer,
                          color: Colors.blue,
                          isTopRow: true,
                        ),
                        ReportAnalyticItem(
                          title: 'Resolution Rate',
                          value:
                              '${((statusCounts['resolved'] ?? 0) / (statusCounts['total'] == 0 ? 1 : statusCounts['total'] ?? 1) * 100).toStringAsFixed(1)}%',
                          icon: Icons.check_circle,
                          color: Colors.green,
                          isTopRow: true,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ReportAnalyticItem(
                          title: 'Pending',
                          value: '${statusCounts['pending'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                        ),
                        ReportAnalyticItem(
                          title: 'In Progress',
                          value: '${statusCounts['in_progress'] ?? 0}',
                          icon: Icons.engineering,
                          color: Colors.blue,
                        ),
                        ReportAnalyticItem(
                          title: 'Resolved',
                          value: '${statusCounts['resolved'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        ReportAnalyticItem(
                          title: 'Rejected',
                          value: '${statusCounts['rejected'] ?? 0}',
                          icon: Icons.block,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ReportAnalyticsCard(
            title: 'Reports by Status',
            children: [
              AspectRatio(
                aspectRatio: 1.5, // Width:Height ratio
                child: PieChart(
                  values: [
                    statusCounts['pending'] ?? 0,
                    statusCounts['in_progress'] ?? 0,
                    statusCounts['resolved'] ?? 0,
                    statusCounts['rejected'] ?? 0,
                  ],
                  colors: const [
                    Colors.orange,
                    Colors.blue,
                    Colors.green,
                    Colors.red,
                  ],
                  labels: [
                    'Pending (${_getPercentage(statusCounts['pending'] ?? 0, statusCounts['total'] ?? 0)}%)',
                    'In Progress (${_getPercentage(statusCounts['in_progress'] ?? 0, statusCounts['total'] ?? 0)}%)',
                    'Resolved (${_getPercentage(statusCounts['resolved'] ?? 0, statusCounts['total'] ?? 0)}%)',
                    'Rejected (${_getPercentage(statusCounts['rejected'] ?? 0, statusCounts['total'] ?? 0)}%)',
                  ],
                  height: 160, // Reduced height

                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ReportAnalyticsCard(
            title: 'Reports by Type',
            children: [
              SizedBox(
                height: 150, // Fixed height for type distribution
                child: typeDistribution.isEmpty
                    ? const Center(
                        child: Text(
                          'No report type data available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        child: ReportTypeDistribution(typeDistribution: typeDistribution),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ReportAnalyticsCard(
            title: 'Weekly Reports Trend',
            children: [
              SizedBox(
                height: 180, // Fixed height for the trend chart
                child: ReportTrendChart(weeklyData: List<int>.from(weeklyData)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  late TabController _tabController;
  String _communityName = '';
  bool _isLoading = true;
  String _selectedFilter = 'All';
  Map<String, dynamic> _reportStats = {
    'statusCounts': {
      'total': 0,
      'pending': 0,
      'in_progress': 0,
      'resolved': 0,
    },
    'typeDistribution': <String, int>{},
    'weeklyData': [0, 0, 0, 0, 0, 0, 0],
    'avgResolutionTime': '0.0',
  };
  final List<String> _tabs = ['Active Reports', 'Resolved', 'Rejected', 'Analytics'];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      _showErrorSnackBar('Error loading community data');
    }
  }

  Future<void> _loadReportStats() async {
    try {
      final stats = await _adminService.getReportStats();
      if (mounted) {
        setState(() => _reportStats = stats);
      }
    } catch (e) {
      _showErrorSnackBar('Error loading report statistics');
    }
  }

  Future<void> _loadReports() async {
    // No need to load reports here since we're using streams
  }

  Future<void> _handleReport(String reportId, String action, {String? resolutionDetails}) async {
    print('Handling report: $reportId with action: $action');
    try {
      await _adminService.updateReportStatus(reportId, action, resolutionDetails: resolutionDetails);
      // Refresh report stats after updating status
      await _loadReportStats();
      _showSuccessSnackBar('Report updated successfully');
    } catch (e) {
      print('Error handling report: $e');
      _showErrorSnackBar('Error updating report: $e');
    }
  }

  // Sign out method removed as it's not used in this context

  void _showReportDetails(Map<String, dynamic> report) {
    print('Showing report details for: ${report['id']}');
    showDialog(
      context: context,
      builder: (context) => ReportDetailDialog(
        report: report,
        onHandleReport: _handleReport,
        onShowResolveDialog: _showResolveDialog,
        onShowRejectDialog: _showRejectDialog,
      ),
    );
  }

  // Assign dialog removed as it's no longer needed

  void _showResolveDialog(String reportId) async {
    final resolution = await ReportActionDialogs.showResolveDialog(context);
    if (resolution != null) {
      _handleReport(reportId, 'resolved', resolutionDetails: resolution);
    }
  }

  void _showRejectDialog(String reportId) async {
    final rejectionReason = await ReportActionDialogs.showRejectDialog(context);
    if (rejectionReason != null) {
      _handleReport(reportId, 'rejected', resolutionDetails: rejectionReason);
    }
  }

  // Unused methods removed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Reports - $_communityName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                      ActiveReportsTab(
                        adminService: _adminService,
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (filter) {
                          setState(() => _selectedFilter = filter);
                        },
                        reportStats: _reportStats,
                        onShowReportDetails: _showReportDetails,
                        onHandleReport: _handleReport,
                        onShowResolveDialog: _showResolveDialog,
                        onShowRejectDialog: _showRejectDialog,
                      ),
                      ResolvedReportsTab(
                        adminService: _adminService,
                        reportStats: _reportStats,
                        onShowReportDetails: _showReportDetails,
                        onHandleReport: _handleReport,
                        onShowResolveDialog: _showResolveDialog,
                        onShowRejectDialog: _showRejectDialog,
                      ),
                      RejectedReportsTab(
                        adminService: _adminService,
                        reportStats: _reportStats,
                        onShowReportDetails: _showReportDetails,
                        onHandleReport: _handleReport,
                        onShowResolveDialog: _showResolveDialog,
                        onShowRejectDialog: _showRejectDialog,
                      ),
                      AnalyticsTab(reportStats: _reportStats),
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
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        tabs: _tabs
            .map((tab) => Tab(
                  text: tab,
                ))
            .toList(),
      ),
    );
  }

}
