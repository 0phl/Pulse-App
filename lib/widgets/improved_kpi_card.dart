import 'package:flutter/material.dart';

class ImprovedKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isPositiveTrend;
  final String? tooltip;

  const ImprovedKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.isPositiveTrend = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      height: 110, // Reduced height for more compact appearance
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
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
          // Trend indicator (if available)
          if (trend != null)
            SizedBox(
              height: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                    size: 12,
                    color: isPositiveTrend ? Colors.green.shade400 : Colors.red.shade400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isPositiveTrend ? Colors.green.shade400 : Colors.red.shade400,
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
