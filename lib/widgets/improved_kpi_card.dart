import 'package:flutter/material.dart';

class ImprovedKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isPositiveTrend;
  final String? tooltip;
  final String? subtitle;

  const ImprovedKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.isPositiveTrend = true,
    this.tooltip,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate trend values dynamically
    Color trendColor = Colors.grey;
    IconData trendIcon = Icons.trending_flat;

    if (trend != null) {
      // Extract numeric value from trend string (removing + or - prefix and % suffix)
      final trendValue =
          double.tryParse(trend!.replaceAll(RegExp(r'[+\-]'), '').replaceAll('%', '')) ?? 0;

      if (trendValue > 0) {
        // If value is positive
        trendIcon = Icons.trending_up;
        trendColor = Colors.green.shade400;
      } else if (trendValue < 0) {
        // If value is negative
        trendIcon = Icons.trending_down;
        trendColor = Colors.red.shade400;
      } else {
        // If value is zero
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey.shade400;
      }
    }

    final cardWidget = Container(
      height: 130, // Increased height to accommodate subtitle
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(158, 158, 158, 0.1), // Using Color.fromRGBO instead of withOpacity
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Title with proper wrapping
          SizedBox(
            width: double.infinity,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1, // Single line for title to save space
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          // Value and icon centered together
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 22,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
          // Subtitle (if available)
          if (subtitle != null)
            SizedBox(
              height: 16,
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),

          // Trend indicator (if available)
          if (trend != null)
            SizedBox(
              height: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    trendIcon,
                    size: 12,
                    color: trendColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 10,
                      color: trendColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    // If tooltip is provided, wrap the card in a tooltip widget
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        preferBelow: true,
        showDuration: const Duration(seconds: 3),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
