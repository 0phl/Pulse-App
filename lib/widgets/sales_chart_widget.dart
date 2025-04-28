import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

// Time period enum for date range selection
enum TimePeriod { week, month, threeMonths, sixMonths, year }

class SalesChartWidget {
  static Widget buildSalesChart(
    Map<String, dynamic> dashboardStats,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color cardBackgroundColor,
    List<BoxShadow> cardShadow, {
    TimePeriod defaultTimePeriod = TimePeriod.week,
    Function(TimePeriod)? onTimePeriodChanged,
  }) {
    return _SalesChartContent(
      dashboardStats: dashboardStats,
      textPrimaryColor: textPrimaryColor,
      textSecondaryColor: textSecondaryColor,
      cardBackgroundColor: cardBackgroundColor,
      cardShadow: cardShadow,
      defaultTimePeriod: defaultTimePeriod,
      onTimePeriodChanged: onTimePeriodChanged,
    );
  }
}

class _SalesChartContent extends StatefulWidget {
  final Map<String, dynamic> dashboardStats;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color cardBackgroundColor;
  final List<BoxShadow> cardShadow;
  final TimePeriod defaultTimePeriod;
  final Function(TimePeriod)? onTimePeriodChanged;

  const _SalesChartContent({
    required this.dashboardStats,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.cardBackgroundColor,
    required this.cardShadow,
    required this.defaultTimePeriod,
    this.onTimePeriodChanged,
  });

  @override
  _SalesChartContentState createState() => _SalesChartContentState();
}

class _SalesChartContentState extends State<_SalesChartContent> with SingleTickerProviderStateMixin {
  late TimePeriod _currentTimePeriod;
  late List<_SalesDataPoint> _salesData;
  late double _totalSales;
  late int _highestValueIndex;
  late int _todayIndex;
  late double _maxValue;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Growth percentage calculated from actual data
  double _growthPercentage = 0.0;

  // Chart colors
  final Color _primaryChartColor = const Color(0xFF00C49A);
  final Color _secondaryChartColor = Colors.tealAccent.shade700;
  final Color _highlightColor = Colors.amber;

  // Map of time periods to their display names
  final Map<TimePeriod, String> _timePeriodLabels = {
    TimePeriod.week: '7 Days',
    TimePeriod.month: '30 Days',
    TimePeriod.threeMonths: '3 Months',
    TimePeriod.sixMonths: '6 Months',
    TimePeriod.year: '1 Year',
  };

  @override
  void initState() {
    super.initState();
    _currentTimePeriod = widget.defaultTimePeriod;

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );

    _processData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SalesChartContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dashboardStats != oldWidget.dashboardStats) {
      _processData();
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _processData() {
    // Extract daily sales data from dashboardStats
    final Map<String, dynamic> dailySales = widget.dashboardStats['dailySales'] ?? {};

    // Debug: Print raw sales data to identify inconsistencies
    debugPrint('Sales Trend - Raw daily sales data: $dailySales');

    // Get the dates in chronological order
    final dateStrings = dailySales.keys.toList();
    dateStrings.sort(); // Sort dates

    // Debug: Print sorted dates
    debugPrint('Sales Trend - Sorted dates: $dateStrings');

    // Get the number of days based on the time period
    final int maxDaysToShow = _getMaxDaysForTimePeriod(_currentTimePeriod);

    // If we have more data than we need, take only the most recent ones
    final startIndex = max(0, dateStrings.length - maxDaysToShow);
    final int numberOfDays = min(dateStrings.length, maxDaysToShow);

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // Raw data points before sampling
    List<_SalesDataPoint> rawData = [];

    // Generate data points for each date
    for (int i = 0; i < numberOfDays; i++) {
      final actualIndex = startIndex + i;
      if (actualIndex >= dateStrings.length) break;

      final dateString = dateStrings[actualIndex];
      final value = (dailySales[dateString] ?? 0).toDouble();

      // Debug: Print each data point being processed
      debugPrint('Sales Trend - Processing data point: Date=$dateString, Value=$value');

      final date = DateTime.parse(dateString);
      final formattedDay = date.day.toString();
      final formattedWeekday = DateFormat('E').format(date);
      final fullWeekday = DateFormat('EEEE').format(date);
      final formattedDate = DateFormat('MMM d, yyyy').format(date);
      final formattedMonth = DateFormat('MMM').format(date);

      rawData.add(_SalesDataPoint(
        date: dateString,
        value: value,
        day: formattedDay,
        weekday: formattedWeekday,
        fullWeekday: fullWeekday,
        formattedDate: formattedDate,
        formattedMonth: formattedMonth,
        index: i,
        dateTime: date,
      ));
    }

    // If no data is available, create some fallback data
    if (rawData.isEmpty) {
      // Get the number of days to show based on time period
      final int daysToShow = _getMaxDaysForTimePeriod(_currentTimePeriod);

      // Generate dates for the selected time period
      DateTime startDate = now.subtract(Duration(days: daysToShow - 1));

      for (int i = 0; i < daysToShow; i++) {
        final date = startDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final formattedDay = date.day.toString();
        final formattedWeekday = DateFormat('E').format(date);
        final fullWeekday = DateFormat('EEEE').format(date);
        final formattedDate = DateFormat('MMM d, yyyy').format(date);
        final formattedMonth = DateFormat('MMM').format(date);

        // Add a spot with minimum value (1) to show a baseline chart
        final value = i == 0 ? 1.0 : 0.0;

        rawData.add(_SalesDataPoint(
          date: dateString,
          value: value,
          day: formattedDay,
          weekday: formattedWeekday,
          fullWeekday: fullWeekday,
          formattedDate: formattedDate,
          formattedMonth: formattedMonth,
          index: i,
          dateTime: date,
        ));
      }
    }

    // Sample data based on time period
    _salesData = _sampleDataForTimePeriod(rawData, _currentTimePeriod);

    // Recalculate indices
    for (int i = 0; i < _salesData.length; i++) {
      _salesData[i] = _salesData[i].copyWith(index: i);
    }

    // Find max value and highest value index
    _maxValue = 0;
    _highestValueIndex = 0;
    _todayIndex = -1;

    for (int i = 0; i < _salesData.length; i++) {
      final data = _salesData[i];

      // Track highest value
      if (data.value > _maxValue) {
        _maxValue = data.value;
        _highestValueIndex = i;
      }

      // Check if this is today's data
      if (data.date == today) {
        _todayIndex = i;
      }
    }

    // If all values are zero, set a default max value
    if (_maxValue == 0) {
      _maxValue = 50; // Set a default max value
    }

    // Calculate total sales
    _totalSales = rawData.fold(0, (sum, item) => sum + item.value);

    // If total sales is provided directly, use that instead
    if (widget.dashboardStats['totalSales'] != null) {
      _totalSales = (widget.dashboardStats['totalSales'] as num).toDouble();
    }

    // Calculate growth percentage based on actual data
    _calculateGrowthPercentage(dailySales);
  }

  // Sample data based on time period to avoid overcrowding
  List<_SalesDataPoint> _sampleDataForTimePeriod(List<_SalesDataPoint> rawData, TimePeriod period) {
    if (rawData.isEmpty) return [];

    // For week, show all data points
    if (period == TimePeriod.week) {
      return List.from(rawData);
    }

    // For other periods, sample data to avoid overcrowding
    int targetPointCount = _getTargetPointCount(period);

    // If we have fewer points than target, return all
    if (rawData.length <= targetPointCount) {
      return List.from(rawData);
    }

    // Group data based on time period
    Map<String, List<_SalesDataPoint>> groupedData = {};

    for (var point in rawData) {
      String key = _getGroupKey(point.dateTime, period);
      if (!groupedData.containsKey(key)) {
        groupedData[key] = [];
      }
      groupedData[key]!.add(point);
    }

    // Create aggregated data points
    List<_SalesDataPoint> sampledData = [];

    // Sort keys to maintain chronological order
    List<String> sortedKeys = groupedData.keys.toList()..sort();

    for (String key in sortedKeys) {
      var points = groupedData[key]!;

      // Calculate average value for this group
      double totalValue = points.fold(0.0, (sum, point) => sum + point.value);
      double avgValue = points.isNotEmpty ? totalValue / points.length : 0;

      // Use the middle point's date for display
      var representativePoint = points[points.length ~/ 2];

      // Create a new data point with aggregated value
      sampledData.add(_SalesDataPoint(
        date: representativePoint.date,
        value: avgValue,
        day: representativePoint.day,
        weekday: representativePoint.weekday,
        fullWeekday: representativePoint.fullWeekday,
        formattedDate: representativePoint.formattedDate,
        formattedMonth: representativePoint.formattedMonth,
        index: representativePoint.index,
        dateTime: representativePoint.dateTime,
      ));
    }

    // Sort by date
    sampledData.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // If we still have too many points, do uniform sampling
    if (sampledData.length > targetPointCount) {
      return _uniformSample(sampledData, targetPointCount);
    }

    return sampledData;
  }

  // Get a key for grouping data points based on time period
  String _getGroupKey(DateTime date, TimePeriod period) {
    switch (period) {
      case TimePeriod.month:
        // Group by every 3 days for month view
        int dayGroup = (date.day - 1) ~/ 3;
        return '${date.year}-${date.month}-$dayGroup';
      case TimePeriod.threeMonths:
        // Group by week for 3 months view
        int weekOfYear = (date.difference(DateTime(date.year, 1, 1)).inDays / 7).floor();
        return '${date.year}-$weekOfYear';
      case TimePeriod.sixMonths:
        // Group by 2 weeks for 6 months view
        int weekOfYear = (date.difference(DateTime(date.year, 1, 1)).inDays / 7).floor();
        int biWeekly = weekOfYear ~/ 2;
        return '${date.year}-$biWeekly';
      case TimePeriod.year:
        // Group by month for year view
        return '${date.year}-${date.month}';
      default:
        return '${date.year}-${date.month}-${date.day}';
    }
  }

  // Get target number of data points based on time period
  int _getTargetPointCount(TimePeriod period) {
    switch (period) {
      case TimePeriod.week:
        return 7;
      case TimePeriod.month:
        return 10; // Show about 10 points for a month
      case TimePeriod.threeMonths:
        return 12; // Show about 12 points for 3 months
      case TimePeriod.sixMonths:
        return 12; // Show about 12 points for 6 months
      case TimePeriod.year:
        return 12; // Show 12 months for a year
      default:
        return 7;
    }
  }

  // Uniform sampling to reduce number of points
  List<_SalesDataPoint> _uniformSample(List<_SalesDataPoint> data, int targetCount) {
    if (data.length <= targetCount) return data;

    List<_SalesDataPoint> result = [];

    // Always include first and last point
    result.add(data.first);

    // Calculate step size for uniform sampling
    double step = (data.length - 2) / (targetCount - 2);

    for (int i = 1; i < targetCount - 1; i++) {
      int index = (i * step).round();
      index = min(index, data.length - 2);
      result.add(data[index]);
    }

    // Add last point
    result.add(data.last);

    return result;
  }

  void _changeTimePeriod(TimePeriod period) {
    setState(() {
      _currentTimePeriod = period;
      _processData();
      _animationController.reset();
      _animationController.forward();
    });

    // Notify parent widget if callback is provided
    if (widget.onTimePeriodChanged != null) {
      widget.onTimePeriodChanged!(period);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive height based on screen width
        final screenWidth = constraints.maxWidth;
        final chartHeight = screenWidth < 360 ? 180.0 : 220.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 360 ? 12 : 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: widget.cardBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sales Trend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.textPrimaryColor,
                        ),
                      ),
                      // Refresh button
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primaryChartColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.sync,
                            color: Color(0xFF00C49A),
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // Refresh data (in a real app, this would fetch new data)
                            setState(() {
                              _processData();
                              _animationController.reset();
                              _animationController.forward();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Time period selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildTimePeriodButton(TimePeriod.week),
                        const SizedBox(width: 8),
                        _buildTimePeriodButton(TimePeriod.month),
                        const SizedBox(width: 8),
                        _buildTimePeriodButton(TimePeriod.threeMonths),
                        const SizedBox(width: 8),
                        _buildTimePeriodButton(TimePeriod.sixMonths),
                        const SizedBox(width: 8),
                        _buildTimePeriodButton(TimePeriod.year),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Total sales with growth indicator
              Row(
                children: [
                  Text(
                    'Total: ${NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(_totalSales)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Growth indicator with tooltip
                  Tooltip(
                    message: _getGrowthTooltipMessage(),
                    child: Row(
                      children: [
                        Icon(
                          _growthPercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: _growthPercentage >= 0 ? _primaryChartColor : Colors.redAccent,
                          size: 12,
                        ),
                        Text(
                          '${_growthPercentage.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _growthPercentage >= 0 ? _primaryChartColor : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return _buildAreaChart();
                  },
                ),
              ),
              // Legend for the chart
              const SizedBox(height: 8),
              SizedBox(
                height: 20,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: [
                    _buildLegendItem(
                      'Highest Sale',
                      _highlightColor,
                      widget.textSecondaryColor,
                    ),
                    if (_todayIndex >= 0)
                      _buildLegendItem(
                        'Today',
                        _primaryChartColor,
                        widget.textSecondaryColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimePeriodButton(TimePeriod period) {
    final isSelected = _currentTimePeriod == period;
    final label = _timePeriodLabels[period] ?? '';

    return InkWell(
      onTap: () => _changeTimePeriod(period),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryChartColor : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : widget.textSecondaryColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAreaChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(_maxValue),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: _buildTitlesData(),
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
        maxX: max(6, (_salesData.length - 1).toDouble()),
        minY: 0,
        maxY: _calculateMaxY(_maxValue),
        lineBarsData: [
          LineChartBarData(
            spots: _salesData.map((data) => FlSpot(data.index.toDouble(), data.value * _animation.value)).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                _primaryChartColor,
                _secondaryChartColor
              ],
            ),
            barWidth: 4,  // Thicker line for area chart
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                Color dotColor = _primaryChartColor;
                double dotSize = 6.0;

                // Highlight highest value with larger dot
                if (index == _highestValueIndex) {
                  dotSize = 8.0;
                  dotColor = _highlightColor;
                }

                // Highlight today's value
                if (index == _todayIndex) {
                  dotSize = 8.0;
                  dotColor = _primaryChartColor;
                }

                return FlDotCirclePainter(
                  radius: dotSize / 2,
                  color: dotColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _primaryChartColor.withOpacity(0.7),  // More opaque at the top
                  _primaryChartColor.withOpacity(0.5),  // Medium opacity in the middle
                  _primaryChartColor.withOpacity(0.3),  // More visible at the bottom
                  _primaryChartColor.withOpacity(0.0),  // Transparent at the very bottom
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: _buildTouchData(),
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
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
          reservedSize: 35,
          getTitlesWidget: (value, meta) {
            if (value >= 0 && value < _salesData.length) {
              final data = _salesData[value.toInt()];

              // Format x-axis labels based on time period
              String primaryLabel = data.day;
              String secondaryLabel = data.weekday;

              switch (_currentTimePeriod) {
                case TimePeriod.week:
                  // For week view, show day and weekday
                  primaryLabel = data.day;
                  secondaryLabel = data.weekday;
                  break;
                case TimePeriod.month:
                  // For month view, show day and month for first day of month
                  primaryLabel = data.day;
                  secondaryLabel = data.dateTime.day == 1 ? data.formattedMonth : data.weekday;
                  break;
                case TimePeriod.threeMonths:
                case TimePeriod.sixMonths:
                  // For 3-6 months view, show day and month
                  primaryLabel = data.day;
                  secondaryLabel = data.formattedMonth;
                  break;
                case TimePeriod.year:
                  // For year view, show month only
                  primaryLabel = data.formattedMonth;
                  secondaryLabel = '';
                  break;
              }

              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: SizedBox(
                  height: 26,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        primaryLabel,
                        style: TextStyle(
                          color: value.toInt() == _todayIndex
                              ? _primaryChartColor
                              : widget.textSecondaryColor,
                          fontSize: 10,
                          fontWeight: value.toInt() == _todayIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (secondaryLabel.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          secondaryLabel,
                          style: TextStyle(
                            color: value.toInt() == _todayIndex
                                ? _primaryChartColor
                                : widget.textSecondaryColor,
                            fontSize: 8,
                            fontWeight: value.toInt() == _todayIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
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
                  color: widget.textSecondaryColor,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.white.withOpacity(0.9),
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        tooltipMargin: 8,
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          return touchedBarSpots.map((barSpot) {
            final flSpot = barSpot;

            // Get data for this spot
            final dateIndex = flSpot.x.toInt();
            if (dateIndex >= 0 && dateIndex < _salesData.length) {
              final data = _salesData[dateIndex];

              return LineTooltipItem(
                '${data.formattedDate} (${data.fullWeekday})\n',
                const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '₱${NumberFormat('#,##0.00').format(flSpot.y)}',
                    style: TextStyle(
                      color: flSpot.y > 0 ? _primaryChartColor : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: '\nRaw date: ${data.date}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }
            return null;
          }).toList();
        },
      ),
      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
        // Handle tap events for future enhancements
        if (event is FlTapUpEvent) {
          final spotIndex = touchResponse?.lineBarSpots?.first.spotIndex;
          if (spotIndex != null && spotIndex >= 0 && spotIndex < _salesData.length) {
            // Future enhancement: Show detailed day info or navigate to details
          }
        }
        return;
      },
    );
  }

  // Helper widget to build legend items
  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: textColor,
          ),
        ),
      ],
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

  // Helper method to get the maximum number of days to display based on time period
  int _getMaxDaysForTimePeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.week:
        return 7;
      case TimePeriod.month:
        return 30;
      case TimePeriod.threeMonths:
        return 90;
      case TimePeriod.sixMonths:
        return 180;
      case TimePeriod.year:
        return 365;
      default:
        return 7;
    }
  }

  // Calculate growth percentage based on actual sales data
  void _calculateGrowthPercentage(Map<String, dynamic> dailySales) {
    // If no sales data is available, set growth to 0
    if (dailySales.isEmpty) {
      _growthPercentage = 0.0;
      debugPrint('Sales Trend - No sales data available, setting growth to 0%');
      return;
    }

    // Get dates in chronological order
    final dateStrings = dailySales.keys.toList();
    dateStrings.sort();

    // If we don't have enough data, set growth to 0
    if (dateStrings.length < 2) {
      _growthPercentage = 0.0;
      debugPrint('Sales Trend - Not enough data points (${dateStrings.length}), setting growth to 0%');
      return;
    }

    // Log the number of data points available
    debugPrint('Sales Trend - Processing ${dateStrings.length} data points');

    // For different time periods, use different comparison approaches
    switch (_currentTimePeriod) {
      case TimePeriod.week:
        _calculateWeeklyGrowth(dateStrings, dailySales);
        break;
      case TimePeriod.month:
        _calculateMonthlyGrowth(dateStrings, dailySales);
        break;
      default:
        _calculateDefaultGrowth(dateStrings, dailySales);
        break;
    }

    // Cap extremely high growth percentages to a more reasonable value (e.g., 200%)
    if (_growthPercentage > 200) {
      debugPrint('Sales Trend - Capping extremely high growth (${_growthPercentage.toStringAsFixed(2)}%) to 200%');
      _growthPercentage = 200;
    }
  }

  // Calculate growth for weekly view (compare most recent days to previous days)
  void _calculateWeeklyGrowth(List<String> dateStrings, Map<String, dynamic> dailySales) {
    // For weekly view, we'll use a more balanced approach to avoid extreme fluctuations

    // If we have a full week of data, compare with previous week
    if (dateStrings.length >= 7) {
      // Calculate total sales for current period (most recent 7 days)
      double currentPeriodSales = 0.0;

      // Get the last 7 days (or all available days if less than 7)
      int daysToUse = min(7, dateStrings.length);

      // Calculate current period (most recent days)
      for (int i = dateStrings.length - 1; i >= dateStrings.length - daysToUse; i--) {
        if (i < 0) break;
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        currentPeriodSales += value;
      }

      // Calculate previous period sales
      double previousPeriodSales = 0.0;

      // If we have data for the previous period
      if (dateStrings.length > daysToUse) {
        int previousDaysAvailable = min(daysToUse, dateStrings.length - daysToUse);

        for (int i = dateStrings.length - daysToUse - 1; i >= dateStrings.length - daysToUse - previousDaysAvailable; i--) {
          if (i < 0) break;
          final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
          previousPeriodSales += value;
        }
      }

      // Calculate average daily sales for both periods to normalize the comparison
      double avgCurrentDailySales = currentPeriodSales / daysToUse;
      double avgPreviousDailySales = previousPeriodSales > 0 ?
          previousPeriodSales / min(daysToUse, dateStrings.length - daysToUse) : 0;

      // Use the average daily sales for growth calculation
      _calculateAndLogGrowth(
        avgCurrentDailySales,
        avgPreviousDailySales,
        'Weekly (Average daily sales comparison)'
      );
    } else {
      // If we have less than 7 days, use the original approach
      // Calculate total sales for current period (most recent days)
      double currentPeriodSales = 0.0;
      int currentDays = 0;

      // Use half of available days for current period
      int daysPerPeriod = max(1, dateStrings.length ~/ 2);

      // Start from the most recent day
      for (int i = dateStrings.length - 1; i >= 0 && currentDays < daysPerPeriod; i--) {
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        currentPeriodSales += value;
        currentDays++;
      }

      // Calculate total sales for previous period
      double previousPeriodSales = 0.0;
      int previousDays = 0;

      // Start from where we left off in the current period
      for (int i = dateStrings.length - currentDays - 1; i >= 0 && previousDays < daysPerPeriod; i--) {
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        previousPeriodSales += value;
        previousDays++;
      }

      _calculateAndLogGrowth(
        currentPeriodSales,
        previousPeriodSales,
        'Weekly (Limited data: $currentDays days vs $previousDays days)'
      );
    }
  }

  // Calculate growth for monthly view
  void _calculateMonthlyGrowth(List<String> dateStrings, Map<String, dynamic> dailySales) {
    // For monthly view, we need a more accurate approach

    // Debug: Print the number of days available for monthly calculation
    debugPrint('Sales Trend - Monthly calculation with ${dateStrings.length} days of data');

    // If we have a full month of data
    if (dateStrings.length >= 30) {
      // Calculate total sales for current period (most recent 15 days)
      double currentPeriodSales = 0.0;
      List<String> currentPeriodDates = [];

      // Get the last 15 days
      for (int i = dateStrings.length - 1; i >= dateStrings.length - 15; i--) {
        if (i < 0) break;
        final dateString = dateStrings[i];
        final value = (dailySales[dateString] ?? 0).toDouble();
        currentPeriodSales += value;
        currentPeriodDates.add(dateString);
      }

      // Calculate total sales for previous period (previous 15 days)
      double previousPeriodSales = 0.0;
      List<String> previousPeriodDates = [];

      for (int i = dateStrings.length - 16; i >= dateStrings.length - 30; i--) {
        if (i < 0) break;
        final dateString = dateStrings[i];
        final value = (dailySales[dateString] ?? 0).toDouble();
        previousPeriodSales += value;
        previousPeriodDates.add(dateString);
      }

      // Debug: Print detailed period information
      debugPrint('Sales Trend - Monthly current period: $currentPeriodSales (${currentPeriodDates.length} days)');
      debugPrint('Sales Trend - Monthly previous period: $previousPeriodSales (${previousPeriodDates.length} days)');

      _calculateAndLogGrowth(currentPeriodSales, previousPeriodSales, 'Monthly (Last 15 days vs Previous 15 days)');
    }
    // If we have less than a full month but more than 15 days
    else if (dateStrings.length > 15) {
      // Calculate total sales for current period (most recent half)
      int halfPoint = dateStrings.length ~/ 2;

      double currentPeriodSales = 0.0;
      for (int i = dateStrings.length - 1; i >= dateStrings.length - halfPoint; i--) {
        if (i < 0) break;
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        currentPeriodSales += value;
      }

      // Calculate total sales for previous period (first half)
      double previousPeriodSales = 0.0;
      for (int i = dateStrings.length - halfPoint - 1; i >= 0; i--) {
        if (i < 0) break;
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        previousPeriodSales += value;
      }

      // Debug: Print detailed period information
      debugPrint('Sales Trend - Monthly (partial) current period: $currentPeriodSales (last $halfPoint days)');
      debugPrint('Sales Trend - Monthly (partial) previous period: $previousPeriodSales (earlier ${dateStrings.length - halfPoint} days)');

      _calculateAndLogGrowth(currentPeriodSales, previousPeriodSales, 'Monthly (Partial data: split in half)');
    }
    // If we have very limited data (15 days or less)
    else {
      // For very limited data, compare most recent third with the rest
      int recentDays = max(1, dateStrings.length ~/ 3);

      double currentPeriodSales = 0.0;
      for (int i = dateStrings.length - 1; i >= dateStrings.length - recentDays; i--) {
        if (i < 0) break;
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        currentPeriodSales += value;
      }

      // Calculate total sales for previous period (remaining days)
      double previousPeriodSales = 0.0;
      for (int i = dateStrings.length - recentDays - 1; i >= 0; i--) {
        final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
        previousPeriodSales += value;
      }

      // Debug: Print detailed period information
      debugPrint('Sales Trend - Monthly (limited) current period: $currentPeriodSales (last $recentDays days)');
      debugPrint('Sales Trend - Monthly (limited) previous period: $previousPeriodSales (earlier ${dateStrings.length - recentDays} days)');

      _calculateAndLogGrowth(currentPeriodSales, previousPeriodSales, 'Monthly (Limited data)');
    }
  }

  // Calculate growth for other time periods
  void _calculateDefaultGrowth(List<String> dateStrings, Map<String, dynamic> dailySales) {
    // For other periods, compare first half with second half
    int halfPoint = dateStrings.length ~/ 2;

    // Calculate total sales for current period (second half - most recent)
    double currentPeriodSales = 0.0;
    for (int i = halfPoint; i < dateStrings.length; i++) {
      final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
      currentPeriodSales += value;
    }

    // Calculate total sales for previous period (first half - older)
    double previousPeriodSales = 0.0;
    for (int i = 0; i < halfPoint; i++) {
      final value = (dailySales[dateStrings[i]] ?? 0).toDouble();
      previousPeriodSales += value;
    }

    _calculateAndLogGrowth(currentPeriodSales, previousPeriodSales, 'Default (Half vs Half)');
  }

  // Helper method to calculate and log growth percentage
  void _calculateAndLogGrowth(double currentPeriodSales, double previousPeriodSales, String method) {
    // Debug: Print raw values before calculation
    debugPrint('Sales Trend - Growth calculation raw values:');
    debugPrint('  - Current period sales: ₱${currentPeriodSales.toStringAsFixed(2)}');
    debugPrint('  - Previous period sales: ₱${previousPeriodSales.toStringAsFixed(2)}');

    // Calculate growth percentage
    if (previousPeriodSales > 0) {
      _growthPercentage = ((currentPeriodSales - previousPeriodSales) / previousPeriodSales) * 100;
      debugPrint('  - Formula used: ((current - previous) / previous) * 100');
      debugPrint('  - Calculation: ((${currentPeriodSales.toStringAsFixed(2)} - ${previousPeriodSales.toStringAsFixed(2)}) / ${previousPeriodSales.toStringAsFixed(2)}) * 100 = ${_growthPercentage.toStringAsFixed(2)}%');
    } else if (currentPeriodSales > 0) {
      // If previous period had no sales but current period does, show 100% growth
      _growthPercentage = 100.0;
      debugPrint('  - Previous period had zero sales, current has sales: Setting to 100%');
    } else {
      // If both periods have no sales, show 0% growth
      _growthPercentage = 0.0;
      debugPrint('  - Both periods have zero sales: Setting to 0%');
    }

    // Store the uncapped value for debugging
    double originalGrowth = _growthPercentage;

    // Cap growth percentage at 200% for display purposes
    if (_growthPercentage > 200) {
      _growthPercentage = 200.0;
      debugPrint('  - Growth capped at 200% (original value: ${originalGrowth.toStringAsFixed(2)}%)');
    }

    // Log the final growth calculation
    debugPrint('Sales Trend - $method Growth: ${_growthPercentage.toStringAsFixed(1)}%');
    debugPrint('  - Current period total: ₱${currentPeriodSales.toStringAsFixed(2)}');
    debugPrint('  - Previous period total: ₱${previousPeriodSales.toStringAsFixed(2)}');
  }

  // Get tooltip message for growth percentage
  String _getGrowthTooltipMessage() {
    String periodType = '';
    String comparison = '';
    String additionalInfo = '';

    switch (_currentTimePeriod) {
      case TimePeriod.week:
        periodType = 'weekly';
        comparison = 'current week vs previous week (daily average)';
        break;
      case TimePeriod.month:
        periodType = 'monthly';
        comparison = 'last 15 days vs previous 15 days';
        break;
      case TimePeriod.threeMonths:
        periodType = '3-month';
        comparison = 'recent half vs earlier half';
        break;
      case TimePeriod.sixMonths:
        periodType = '6-month';
        comparison = 'recent half vs earlier half';
        break;
      case TimePeriod.year:
        periodType = 'yearly';
        comparison = 'recent half vs earlier half';
        break;
    }

    // Add additional info for high growth rates
    if (_growthPercentage >= 100) {
      additionalInfo = '\n\nNote: High growth rates may occur when comparing to periods with low sales.';

      // Debug: Log the tooltip message being generated
      debugPrint('Sales Trend - Showing high growth rate tooltip: $_growthPercentage%');
    }

    // Add additional info for capped growth rates
    if (_growthPercentage == 200) {
      additionalInfo = '\n\nNote: Actual growth exceeds 200% and has been capped for display purposes.';

      // Debug: Log that growth was capped
      debugPrint('Sales Trend - Growth was capped at 200% for display');
    }

    // Add additional info for 30-day view with limited data
    if (_currentTimePeriod == TimePeriod.month) {
      // We don't have access to dateStrings here, so we'll just add a general note
      additionalInfo += '\n\nNote: Growth calculation depends on available data in the selected period.';

      // Debug: Log the tooltip being shown
      debugPrint('Sales Trend - Added data availability note to tooltip');
    }

    return 'Sales growth ($periodType): ${_growthPercentage >= 0 ? '+' : ''}${_growthPercentage.toStringAsFixed(1)}%\nComparing $comparison$additionalInfo';
  }
}

// Helper class to store sales data points
class _SalesDataPoint {
  final String date;
  final double value;
  final String day;
  final String weekday;
  final String fullWeekday;
  final String formattedDate;
  final String formattedMonth;
  final int index;
  final DateTime dateTime;

  _SalesDataPoint({
    required this.date,
    required this.value,
    required this.day,
    required this.weekday,
    required this.fullWeekday,
    required this.formattedDate,
    this.formattedMonth = '',
    required this.index,
    required this.dateTime,
  });

  // Create a copy with new index
  _SalesDataPoint copyWith({int? index}) {
    return _SalesDataPoint(
      date: date,
      value: value,
      day: day,
      weekday: weekday,
      fullWeekday: fullWeekday,
      formattedDate: formattedDate,
      formattedMonth: formattedMonth,
      index: index ?? this.index,
      dateTime: dateTime,
    );
  }
}
