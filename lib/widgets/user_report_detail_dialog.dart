import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/report.dart';
import '../models/report_status.dart';
import '../widgets/image_viewer_page.dart';
import '../widgets/video_player_page.dart';
import '../widgets/video_thumbnail.dart';

class UserReportDetailDialog extends StatelessWidget {
  final Report report;

  const UserReportDetailDialog({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        DateFormat('MMMM d, y • h:mm a').format(report.createdAt);

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
                color: _getStatusColor(report.status),
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
                          report.issueType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report #${report.id}',
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
                      _getStatusText(report.status),
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
                      report.address,
                      Icons.location_on,
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _buildSectionTitle('Description'),
                    Text(
                      report.description,
                      style: const TextStyle(fontSize: 14),
                    ),

                    // Resolution or rejection details
                    if ((report.status == ReportStatus.resolved || report.status == ReportStatus.rejected) && report.resolutionDetails != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle(report.status == ReportStatus.rejected ? 'Rejection Reason' : 'Resolution Details'),
                      Text(
                        report.resolutionDetails!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],

                    if (report.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Photos'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: report.photoUrls.length,
                          itemBuilder: (context, index) {
                            final imageUrl = report.photoUrls[index];
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

                    if (report.videoUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Videos'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: report.videoUrls.length,
                          itemBuilder: (context, index) {
                            final videoUrl = report.videoUrls[index];
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
                  ],
                ),
              ),
            ),

            // Close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C49A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
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

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.underReview:
        return Colors.blue;
      case ReportStatus.inProgress:
        return Colors.purple;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(ReportStatus status) {
    return status.value
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}