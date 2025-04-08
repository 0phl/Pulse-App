import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class EngagementReportCard extends StatelessWidget {
  final Map<String, dynamic> engagementData;

  const EngagementReportCard({
    super.key,
    required this.engagementData,
  });

  @override
  Widget build(BuildContext context) {
    final engagementRate = engagementData['engagementRate'] as int? ?? 0;
    final engagementComponents =
        engagementData['engagementComponents'] as Map<String, dynamic>? ?? {};

    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.insights,
                    size: 24,
                    color: const Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Engagement Report',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A90E2),
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Engagement rate circle
                    CircularPercentIndicator(
                      radius: 50.0,
                      lineWidth: 8.0,
                      percent: engagementRate / 100,
                      center: Text(
                        '$engagementRate%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      progressColor: _getColorForRate(engagementRate),
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      circularStrokeCap: CircularStrokeCap.round,
                      animation: true,
                      animationDuration: 1500,
                    ),

                    const SizedBox(width: 16),

                    // Engagement components
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildComponentRow(
                            'User Interactions',
                            engagementComponents['userLikesComments'] ?? 0,
                            Icons.favorite,
                            const Color(0xFFE57373),
                          ),
                          const SizedBox(height: 8),
                          _buildComponentRow(
                            'Volunteer Participation',
                            engagementComponents['volunteerParticipation'] ?? 0,
                            Icons.volunteer_activism,
                            const Color(0xFF81C784),
                          ),
                          const SizedBox(height: 8),
                          _buildComponentRow(
                            'Marketplace Activity',
                            engagementComponents['marketplaceActivity'] ?? 0,
                            Icons.shopping_cart,
                            const Color(0xFFF5A623),
                          ),
                          const SizedBox(height: 8),
                          _buildComponentRow(
                            'Report Submissions',
                            engagementComponents['reportSubmissions'] ?? 0,
                            Icons.report_problem,
                            const Color(0xFFBA68C8),
                          ),
                          const SizedBox(height: 8),
                          _buildComponentRow(
                            'Admin Interactions',
                            engagementComponents['adminInteractions'] ?? 0,
                            Icons.admin_panel_settings,
                            const Color(0xFF4A90E2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Engagement description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Engagement rate is calculated based on user interactions, volunteer participation, marketplace activity, report submissions, and admin interactions relative to the total possible activities for your community size.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(
      String label, int value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            overflow: TextOverflow.visible,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getColorForRate(int rate) {
    if (rate >= 75) {
      return const Color(0xFF81C784); // Green
    } else if (rate >= 50) {
      return const Color(0xFF4A90E2); // Blue
    } else if (rate >= 25) {
      return const Color(0xFFF5A623); // Orange
    } else {
      return const Color(0xFFE57373); // Red
    }
  }
}
