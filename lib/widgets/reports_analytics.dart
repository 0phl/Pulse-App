import 'package:flutter/material.dart';

class ReportAnalyticsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ReportAnalyticsCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar with subtle background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportAnalyticItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isTopRow;

  const ReportAnalyticItem({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isTopRow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isTopRow ? 100 : 75, // Wider for top row items
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTopRow ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isTopRow ? 20 : 18),
          ),
          SizedBox(height: isTopRow ? 8 : 6),
          Text(
            title,
            style: TextStyle(
              fontSize: isTopRow ? 12 : 11,
              color: Colors.grey[600],
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isTopRow ? 4 : 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ReportStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportTypeDistribution extends StatelessWidget {
  final Map<String, dynamic> typeDistribution;

  const ReportTypeDistribution({
    super.key,
    required this.typeDistribution,
  });

  @override
  Widget build(BuildContext context) {
    final entries = typeDistribution.entries.map((entry) =>
      MapEntry(entry.key, entry.value as int)).toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    // Professional color for all bars
    const Color barColor = Color(0xFF2196F3); // Professional blue
    const Color percentageColor = Color(0xFF757575); // Gray for percentage text

    return Column(
      children: entries.map((entry) {
        final double percentage = total > 0 ? (entry.value / total * 100) : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: percentageColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: barColor,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ReportTrendChart extends StatelessWidget {
  final List<int> weeklyData;

  const ReportTrendChart({
    super.key,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    print('ReportTrendChart received weeklyData: $weeklyData');
    final int maxValue =
        weeklyData.isNotEmpty ? weeklyData.reduce((a, b) => a > b ? a : b) : 0;
    print('Max value for chart: $maxValue');

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y-axis
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$maxValue',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text('${(maxValue / 2).round()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const Text('0',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 8),

          // Chart
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weeklyData.length, (index) {
                final value = weeklyData[index];
                final height = maxValue > 0 ? (value / maxValue) * 150 : 0.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: height,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C49A),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x2000C49A),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDayLabel(index),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(int index) {
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index % days.length];
  }
}
