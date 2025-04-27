import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class SalesChartWidget {
  static Widget buildSalesChart(
    Map<String, dynamic> dashboardStats,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color cardBackgroundColor,
    List<BoxShadow> cardShadow,
  ) {
    // Extract daily sales data from dashboardStats
    final Map<String, dynamic> dailySales = dashboardStats['dailySales'] ?? {};

    // Convert to a list of FlSpots for the chart
    List<FlSpot> spots = [];
    List<String> dates = []; // Store dates for tooltip
    double maxValue = 0; // Track max value for Y axis scaling

    // Get the dates in chronological order
    final dateStrings = dailySales.keys.toList();
    dateStrings.sort(); // Sort dates

    // Only show up to 7 days
    final int numberOfDays = min(dateStrings.length, 7);

    // Generate spots for each date
    for (int i = 0; i < numberOfDays; i++) {
      final dateString = dateStrings[i];
      final value = (dailySales[dateString] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      dates.add(dateString);
      if (value > maxValue) {
        maxValue = value;
      }
    }

    // If no data is available or all values are zero, create some fallback data
    if (spots.isEmpty || maxValue == 0) {
      // Generate dates for the last 7 days
      final now = DateTime.now();
      DateTime startDate =
          now.subtract(Duration(days: min(6, numberOfDays - 1)));
      spots = [];
      dates = [];

      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        dates.add(dateString);

        // Add a spot with minimum value (1) to show a baseline chart
        spots.add(FlSpot(i.toDouble(), i == 0 ? 1 : 0));
      }

      maxValue = 50; // Set a default max value
    }

    // Return the sales chart widget
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              // Refresh indicator to show this is real-time data
              const Icon(
                Icons.sync,
                color: Color(0xFF00C49A),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateInterval(maxValue),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < dates.length) {
                          // Parse the date and get the day
                          final date = DateTime.parse(dates[value.toInt()]);
                          final day = date.day.toString();

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              day,
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: const Text(''),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        // Show abbreviated price on y-axis
                        String text = '';
                        if (value == 0) {
                          text = '₱0';
                        } else if (value >= 1000) {
                          text = '₱${(value / 1000).toStringAsFixed(0)}K';
                        } else {
                          text = '₱${value.toInt()}';
                        }

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            text,
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    left: BorderSide(color: Colors.grey[200]!, width: 1),
                    top: BorderSide.none,
                    right: BorderSide.none,
                  ),
                ),
                minX: 0,
                maxX: max(6, (numberOfDays - 1).toDouble()),
                minY: 0,
                maxY: _calculateMaxY(maxValue),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, // Use the processed daily sales spots
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00C49A),
                        Colors.tealAccent.shade700
                      ],
                    ),
                    barWidth: 3, // Slightly thinner line
                    isStrokeCapRound: true,
                    dotData:
                        const FlDotData(show: true), // Show dots on the line
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00C49A).withOpacity(0.3),
                          Colors.tealAccent.shade700.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true, // Enable default touch behaviors
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.white.withOpacity(0.8),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;

                        // Parse date to display in a more readable format
                        final dateIndex = flSpot.x.toInt();
                        if (dateIndex >= 0 && dateIndex < dates.length) {
                          final dateString = dates[dateIndex];
                          final date = DateTime.parse(dateString);
                          final formattedDate =
                              DateFormat('MMM d, yyyy').format(date);

                          return LineTooltipItem(
                            '$formattedDate\n', // Date on first line
                            TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '₱${NumberFormat('#,##0.00').format(flSpot.y)}', // Sales amount
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to calculate appropriate interval for Y axis
  static double _calculateInterval(double maxValue) {
    if (maxValue <= 10) return 1;
    if (maxValue <= 100) return 10;
    if (maxValue <= 500) return 50;
    if (maxValue <= 1000) return 100;
    if (maxValue <= 5000) return 500;
    return 1000;
  }

  // Helper method to calculate appropriate max Y value
  static double _calculateMaxY(double maxValue) {
    if (maxValue <= 0) return 50; // Default minimum

    // Round up to a nice number
    if (maxValue <= 10) return (maxValue + 2).ceilToDouble();
    if (maxValue <= 100) return (maxValue + 20).ceilToDouble();
    if (maxValue <= 500) return (maxValue + 50).ceilToDouble();
    if (maxValue <= 1000) return (maxValue + 100).ceilToDouble();

    return maxValue * 1.2; // Add 20% padding for larger values
  }
}
