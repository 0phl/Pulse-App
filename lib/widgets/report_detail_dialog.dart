import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportDetailDialog extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(String, String) onHandleReport;
  final Function(String) onAssign;
  final Function(String) onAddNote;
  final Function(String) onShowResolveDialog;

  const ReportDetailDialog({
    Key? key,
    required this.report,
    required this.onHandleReport,
    required this.onAssign,
    required this.onAddNote,
    required this.onShowResolveDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String status = report['status'] ?? 'pending';
    final Timestamp createdAt = report['createdAt'] as Timestamp;
    final String formattedDate =
        DateFormat('MMMM d, y • h:mm a').format(createdAt.toDate());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['type'] ?? 'Unknown Type',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report #${report['id']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reporter info
                    _buildSectionTitle('Reporter Information'),
                    _buildInfoRow(
                      'Name',
                      report['reporterName'] ?? 'Anonymous',
                      Icons.person,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Email',
                      report['reporterEmail'] ?? 'N/A',
                      Icons.email,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Phone',
                      report['reporterPhone'] ?? 'N/A',
                      Icons.phone,
                    ),

                    const SizedBox(height: 16),

                    // Report details
                    _buildSectionTitle('Report Details'),
                    _buildInfoRow(
                      'Reported On',
                      formattedDate,
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Location',
                      report['address'] ?? 'No location provided',
                      Icons.location_on,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Priority',
                      _capitalizeFirst(report['priority'] ?? 'medium'),
                      Icons.flag,
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _buildSectionTitle('Description'),
                    Text(
                      report['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 14),
                    ),

                    if (report['imageUrl'] != null &&
                        report['imageUrl'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Image'),
                      const SizedBox(height: 8),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            report['imageUrl'],
                            fit: BoxFit.cover,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                                child: const Text('Image not available'),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    if (report['assignedTo'] != null &&
                        report['assignedTo'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Assigned To'),
                      Text(
                        report['assignedTo'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],

                    if (report['notes'] != null &&
                        report['notes'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Notes'),
                      Text(
                        report['notes'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],

                    if (report['resolution'] != null &&
                        report['resolution'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Resolution'),
                      Text(
                        report['resolution'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (status == 'pending')
                    _buildActionButton(
                      label: 'Assign',
                      icon: Icons.person_add,
                      color: Colors.indigo,
                      onPressed: () {
                        Navigator.pop(context);
                        onAssign(report['id']);
                      },
                    ),
                  if (status == 'pending')
                    _buildActionButton(
                      label: 'Start',
                      icon: Icons.play_arrow,
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pop(context);
                        onHandleReport(report['id'], 'in_progress');
                      },
                    ),
                  if (status == 'in_progress')
                    _buildActionButton(
                      label: 'Resolve',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onPressed: () {
                        Navigator.pop(context);
                        onShowResolveDialog(report['id']);
                      },
                    ),
                  if (status != 'resolved' && status != 'rejected')
                    _buildActionButton(
                      label: 'Add Note',
                      icon: Icons.note_add,
                      color: const Color(0xFF00C49A),
                      onPressed: () {
                        Navigator.pop(context);
                        onAddNote(report['id']);
                      },
                    ),
                  _buildActionButton(
                    label: 'Close',
                    icon: Icons.close,
                    color: Colors.grey,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'resolved':
        return 'RESOLVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'UNKNOWN';
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
