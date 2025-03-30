import 'package:flutter/material.dart';

class ReportStyles {
  // Colors
  static const primaryColor = Color(0xFF00C49A);
  
  // Status Colors
  static const statusColors = {
    'pending': Colors.orange,
    'in_progress': Colors.blue,
    'resolved': Colors.green,
    'rejected': Colors.red,
  };

  // Report Type Icons
  static IconData getReportTypeIcon(String? type) {
    switch (type) {
      case 'Street Light Damage':
        return Icons.lightbulb_outline;
      case 'Road Damage/Potholes':
        return Icons.wrong_location;
      case 'Garbage Collection Problems':
        return Icons.delete_outline;
      case 'Flooding/Drainage Issues':
        return Icons.water_damage;
      case 'Vandalism':
        return Icons.broken_image;
      case 'Noise Complaint':
        return Icons.volume_up;
      case 'Safety Hazard':
        return Icons.warning;
      default:
        return Icons.report_problem;
    }
  }

  // Status Text
  static String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  // Get status color
  static Color getStatusColor(String status) {
    return statusColors[status] ?? Colors.grey;
  }

  // Typography
  static const titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const subtitleStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  // Dimensions
  static const double cardBorderRadius = 8.0;
  static const double cardPadding = 16.0;
  static const double cardElevation = 1.0;

  // Status Chip Styles
  static ChipThemeData statusChipTheme(Color color) {
    return ChipThemeData(
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(cardBorderRadius),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.1),
        spreadRadius: 1,
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Loading State
  static const loadingIndicatorColor = primaryColor;
  static final loadingOverlayColor = Colors.black.withOpacity(0.3);

  // Empty State
  static const emptyStateIconSize = 64.0;
  static final emptyStateIconColor = Colors.grey[300];
  static final emptyStateTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.grey[600],
  );
}
