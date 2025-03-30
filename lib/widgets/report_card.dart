import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/report_styles.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(String) onViewDetails;
  final Function(String, String) onHandleReport;
  final Function(String) onAssign;
  final Function(String) onShowResolveDialog;

  const ReportCard({
    Key? key,
    required this.report,
    required this.onViewDetails,
    required this.onHandleReport,
    required this.onAssign,
    required this.onShowResolveDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String status = report['status'] ?? 'pending';
    final Timestamp createdAt = report['createdAt'] as Timestamp;
    final String formattedDate =
        DateFormat('MMM d, y • h:mm a').format(createdAt.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ReportStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and status
          Container(
            decoration: BoxDecoration(
              color: ReportStyles.getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ReportStyles.cardBorderRadius),
                topRight: Radius.circular(ReportStyles.cardBorderRadius),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  ReportStyles.getReportTypeIcon(report['type']),
                  color: ReportStyles.getStatusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report['type'] ?? 'Unknown Type',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    chipTheme: ReportStyles.statusChipTheme(ReportStyles.getStatusColor(status)),
                  ),
                  child: Chip(
                    label: Text(ReportStyles.getStatusText(status)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Report content
          Padding(
            padding: EdgeInsets.all(ReportStyles.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reporter info
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report['reporterName'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  report['description'] ?? 'No description provided.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 12),

                // Location
                if (report['address'] != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report['address'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending')
                      TextButton.icon(
                        onPressed: () => onAssign(report['id']),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Assign'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (status == 'pending')
                      TextButton.icon(
                        onPressed: () =>
                            onHandleReport(report['id'], 'in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (status == 'in_progress')
                      TextButton.icon(
                        onPressed: () => onShowResolveDialog(report['id']),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Resolve'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => onViewDetails(report['id']),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: ReportStyles.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
