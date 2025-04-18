import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/image_viewer_page.dart';
import '../widgets/video_player_page.dart';
import '../widgets/video_thumbnail.dart';

class ReportDetailDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final Function(String, String) onHandleReport;
  final Function(String) onShowResolveDialog;
  final Function(String)? onShowRejectDialog;

  const ReportDetailDialog({
    super.key,
    required this.report,
    required this.onHandleReport,
    required this.onShowResolveDialog,
    this.onShowRejectDialog,
  });

  @override
  State<ReportDetailDialog> createState() => _ReportDetailDialogState();
}

class _ReportDetailDialogState extends State<ReportDetailDialog> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = widget.report['userId'];
      if (userId != null) {
        final userSnapshot = await _database.ref().child('users/$userId').get();
        if (userSnapshot.exists) {
          final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
          setState(() {
            _userData = userData;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String status = widget.report['status'] ?? 'pending';
    final Timestamp createdAt = widget.report['createdAt'] as Timestamp;
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
                          widget.report['issueType'] ?? 'Unknown Type',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report #${widget.report['id']}',
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
                    _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Name',
                              _userData?['fullName'] ?? 'Anonymous',
                              Icons.person,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Email',
                              _userData?['email'] ?? 'N/A',
                              Icons.email,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Phone',
                              _userData?['mobile'] ?? 'N/A',
                              Icons.phone,
                            ),
                          ],
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
                      widget.report['address'] ?? 'No location provided',
                      Icons.location_on,
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _buildSectionTitle('Description'),
                    Text(
                      widget.report['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 14),
                    ),

                    // Images section
                    if (widget.report['photoUrls'] != null &&
                        (widget.report['photoUrls'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Images'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (widget.report['photoUrls'] as List).length,
                          itemBuilder: (context, index) {
                            final imageUrl = (widget.report['photoUrls'] as List)[index].toString();
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 200,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageViewerPage(
                                        imageUrl: imageUrl,
                                      ),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: imageUrl,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          alignment: Alignment.center,
                                          child: const Text('Image not available'),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Videos section
                    if (widget.report['videoUrls'] != null &&
                        (widget.report['videoUrls'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Videos'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (widget.report['videoUrls'] as List).length,
                          itemBuilder: (context, index) {
                            final videoUrl = (widget.report['videoUrls'] as List)[index].toString();
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 200,
                              height: 200,
                              child: VideoThumbnail(
                                videoUrl: videoUrl,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerPage(
                                        videoUrl: videoUrl,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    if (widget.report['resolution'] != null &&
                        widget.report['resolution'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Resolution'),
                      Text(
                        widget.report['resolution'],
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
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8, // horizontal spacing
                runSpacing: 8, // vertical spacing
                children: [
                  // Assign button completely removed
                  if (status == 'pending') ...[
                    _buildActionButton(
                      label: 'Start',
                      icon: Icons.play_arrow,
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onHandleReport(widget.report['id'], 'in_progress');
                      },
                    ),
                    if (widget.onShowRejectDialog != null)
                      _buildActionButton(
                        label: 'Reject',
                        icon: Icons.cancel,
                        color: Colors.red,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onShowRejectDialog!(widget.report['id']);
                        },
                      ),
                  ],
                  if (status == 'in_progress') ...[
                    _buildActionButton(
                      label: 'Resolve',
                      icon: Icons.task_alt,
                      color: Colors.green,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onShowResolveDialog(widget.report['id']);
                      },
                    ),
                    if (widget.onShowRejectDialog != null)
                      _buildActionButton(
                        label: 'Reject',
                        icon: Icons.cancel,
                        color: Colors.red,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onShowRejectDialog!(widget.report['id']);
                        },
                      ),
                  ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        elevation: 2,
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

  // Helper method removed as it's no longer needed
}
