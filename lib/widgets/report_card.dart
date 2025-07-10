import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../constants/report_styles.dart';

class ReportCard extends StatelessWidget {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final Map<String, String> _userNameCache = {};

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final userSnapshot = await _database.ref().child('users').child(userId).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final fullName = userData['fullName'] as String? ?? 'User';

        // Cache the result
        _userNameCache[userId] = fullName;
        return fullName;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return 'User';
  }
  final Map<String, dynamic> report;
  final Function(String) onViewDetails;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String)? onShowRejectDialog;

  const ReportCard({
    Key? key,
    required this.report,
    required this.onViewDetails,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    this.onShowRejectDialog,
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
                  ReportStyles.getReportTypeIcon(report['issueType']),
                  color: ReportStyles.getStatusColor(status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report['issueType'] ?? 'Unknown Type',
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
                    FutureBuilder<String>(
                      future: _getUserName(report['userId']),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
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
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8, // horizontal spacing
                  runSpacing: 8, // vertical spacing
                  children: [
                    if (status == 'pending') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          final reportId = report['id'];
                          if (reportId != null) {
                            // Print debug info removed
                            onHandleReport(reportId, 'in_progress');
                          }
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                          elevation: 2,
                        ),
                      ),
                      if (onShowRejectDialog != null) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            final reportId = report['id'];
                            if (reportId != null) {
                              onShowRejectDialog!(reportId);
                            }
                          },
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                            elevation: 2,
                          ),
                        ),
                      ],
                    ],
                    if (status == 'in_progress') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          final reportId = report['id'];
                          if (reportId != null) {
                            onShowResolveDialog(reportId);
                          }
                        },
                        icon: const Icon(Icons.task_alt, size: 16),
                        label: const Text('Mark Resolved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                          elevation: 2,
                        ),
                      ),
                      if (onShowRejectDialog != null) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            final reportId = report['id'];
                            if (reportId != null) {
                              onShowRejectDialog!(reportId);
                            }
                          },
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                            elevation: 2,
                          ),
                        ),
                      ],
                    ],

                    OutlinedButton.icon(
                      onPressed: () {
                        final reportId = report['id'];
                        if (reportId != null) {
                          // Print debug info removed
                          onViewDetails(reportId);
                        }
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ReportStyles.primaryColor,
                        side: const BorderSide(color: ReportStyles.primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
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
