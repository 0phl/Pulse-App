import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import './admin_drawer.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _adminService = AdminService();
  final _authService = AuthService();
  String _communityName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadCommunity();
    _loadReports();
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
        title: const Text('Reports'),
      ),
      drawer: const AdminDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('No reports to review'))
              : ListView.builder(
                  itemCount: _reports.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text('Report #${report['id']}'),
                        subtitle: Text(
                            'Type: ${report['type']} • Status: ${report['status']}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reported by: ${report['reporterEmail']}'),
                                const SizedBox(height: 8),
                                Text('Description: ${report['description']}'),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _handleReport(
                                        report['id'],
                                        'dismissed',
                                      ),
                                      child: const Text('Dismiss'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _handleReport(
                                        report['id'],
                                        'action_taken',
                                      ),
                                      child: const Text('Take Action'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // TODO: Implement loading reports from Firestore
      // This is a placeholder for demo
      setState(() {
        _reports = [
          {
            'id': '1',
            'type': 'Inappropriate Content',
            'status': 'pending',
            'reporterEmail': 'user@example.com',
            'description': 'This post contains inappropriate content',
          }
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReport(String reportId, String action) async {
    try {
      await _adminService.handleReport(reportId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report $action successfully')),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error handling report: $e')),
        );
      }
    }
  }
}
