import 'package:flutter/material.dart';
import '../models/report.dart';
import '../constants/report_styles.dart';
import 'package:intl/intl.dart';

class RecentReportsWidget extends StatelessWidget {
  final List<Report> reports;
  final Function(Map<String, dynamic>) onViewDetails;

  const RecentReportsWidget({
    super.key,
    required this.reports,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/reports');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent reports',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length > 3 ? 3 : reports.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportItem(report);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildReportItem(Report report) {
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(report.createdAt);
    
    return InkWell(
      onTap: () => onViewDetails(report.toMap()),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ReportStyles.getStatusColor(report.status.value).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                ReportStyles.getReportTypeIcon(report.issueType),
                color: ReportStyles.getStatusColor(report.status.value),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.issueType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ReportStyles.getStatusColor(report.status.value).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ReportStyles.getStatusText(report.status.value),
                style: TextStyle(
                  fontSize: 12,
                  color: ReportStyles.getStatusColor(report.status.value),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
