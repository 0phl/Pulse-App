import 'package:flutter/material.dart';

class ReportsSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> reportStats;

  const ReportsSummaryWidget({
    super.key,
    required this.reportStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Reports Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          // Top row with overall stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.assessment,
                  iconColor: Colors.teal,
                  iconBgColor: Colors.teal.withOpacity(0.1),
                  title: 'Total Reports',
                  value: '${reportStats['totalReports'] ?? 0}',
                ),
                _buildStatItem(
                  icon: Icons.timer,
                  iconColor: Colors.blue,
                  iconBgColor: Colors.blue.withOpacity(0.1),
                  title: 'Avg. Resolution Time',
                  value: '${reportStats['avgResolutionTime'] ?? '0'} days',
                ),
                _buildStatItem(
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  iconBgColor: Colors.green.withOpacity(0.1),
                  title: 'Resolution Rate',
                  value: '${reportStats['resolutionRate'] ?? 0}%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          // Bottom row with status counts
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  icon: Icons.pending,
                  iconColor: Colors.orange,
                  iconBgColor: Colors.orange.withOpacity(0.1),
                  title: 'Pending',
                  value: '${reportStats['pendingCount'] ?? 0}',
                ),
                _buildStatusItem(
                  icon: Icons.sync,
                  iconColor: Colors.blue,
                  iconBgColor: Colors.blue.withOpacity(0.1),
                  title: 'In Progress',
                  value: '${reportStats['inProgressCount'] ?? 0}',
                ),
                _buildStatusItem(
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  iconBgColor: Colors.red.withOpacity(0.1),
                  title: 'Rejected',
                  value: '${reportStats['rejectedCount'] ?? 0}',
                ),
                _buildStatusItem(
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green,
                  iconBgColor: Colors.green.withOpacity(0.1),
                  title: 'Resolved',
                  value: '${reportStats['resolvedCount'] ?? 0}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
