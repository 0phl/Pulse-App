import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

// Chart type enum for switching between visualizations
enum ChartType { line, bar, area }

class SalesChartWidget {
  static Widget buildSalesChart(
    Map<String, dynamic> dashboardStats,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color cardBackgroundColor,
    List<BoxShadow> cardShadow, {
    ChartType defaultChartType = ChartType.line,
  }) {
    return _SalesChartContent(
      dashboardStats: dashboardStats,
      textPrimaryColor: textPrimaryColor,
      textSecondaryColor: textSecondaryColor,
      cardBackgroundColor: cardBackgroundColor,
      cardShadow: cardShadow,
      defaultChartType: defaultChartType,
    );
  }
}

class _SalesChartContent extends StatefulWidget {
  final Map<String, dynamic> dashboardStats;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color cardBackgroundColor;
  final List<BoxShadow> cardShadow;
  final ChartType defaultChartType;

  const _SalesChartContent({
    required this.dashboardStats,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.cardBackgroundColor,
    required this.cardShadow,
    required this.defaultChartType,
  });

  @override
  _SalesChartContentState createState() => _SalesChartContentState();
}

class _SalesChartContentState extends State<_SalesChartContent> with SingleTickerProviderStateMixin {
  late ChartType _currentChartType;
  late List<_SalesDataPoint> _salesData;
  late double _totalSales;
  late int _highestValueIndex;
  late int _todayIndex;
  late double _maxValue;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Growth percentage (could be calculated from actual data)
  final double _growthPercentage = 12.5;

  // Chart colors
  final Color _primaryChartColor = const Color(0xFF00C49A);
  final Color _secondaryChartColor = Colors.tealAccent.shade700;
  final Color _highlightColor = Colors.amber;

  @override
  void initState() {
    super.initState();
    _currentChartType = widget.defaultChartType;
    _processData();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
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

    // Get the dates in chronological order
    final dateStrings = dailySales.keys.toList();
    dateStrings.sort(); // Sort dates

    // Only show up to 7 days
    final int numberOfDays = min(dateStrings.length, 7);
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    _salesData = [];
    _maxValue = 0;
    _highestValueIndex = 0;
    _todayIndex = -1;

    // Generate data points for each date
    for (int i = 0; i < numberOfDays; i++) {
      final dateString = dateStrings[i];
      final value = (dailySales[dateString] ?? 0).toDouble();

      final date = DateTime.parse(dateString);
      final formattedDay = date.day.toString();
      final formattedWeekday = DateFormat('E').format(date);
      final fullWeekday = DateFormat('EEEE').format(date);
      final formattedDate = DateFormat('MMM d, yyyy').format(date);

      _salesData.add(_SalesDataPoint(
        date: dateString,
        value: value,
        day: formattedDay,
        weekday: formattedWeekday,
        fullWeekday: fullWeekday,
        formattedDate: formattedDate,
        index: i,
      ));

      // Track highest value
      if (value > _maxValue) {
        _maxValue = value;
        _highestValueIndex = i;
      }

      // Check if this is today's data
      if (dateString == today) {
        _todayIndex = i;
      }
    }

    // If no data is available or all values are zero, create some fallback data
    if (_salesData.isEmpty || _maxValue == 0) {
      // Generate dates for the last 7 days
      DateTime startDate = now.subtract(Duration(days: min(6, numberOfDays - 1)));

      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final formattedDay = date.day.toString();
        final formattedWeekday = DateFormat('E').format(date);
        final fullWeekday = DateFormat('EEEE').format(date);
        final formattedDate = DateFormat('MMM d, yyyy').format(date);

        // Add a spot with minimum value (1) to show a baseline chart
        final value = i == 0 ? 1.0 : 0.0;

        _salesData.add(_SalesDataPoint(
          date: dateString,
          value: value,
          day: formattedDay,
          weekday: formattedWeekday,
          fullWeekday: fullWeekday,
          formattedDate: formattedDate,
          index: i,
        ));

        // Check if this is today's data
        if (dateString == today) {
          _todayIndex = i;
        }
      }

      _maxValue = 50; // Set a default max value
      _highestValueIndex = 0; // Default highest value index
    }

    // Calculate total sales
    _totalSales = _salesData.fold(0, (sum, item) => sum + item.value);

    // If total sales is provided directly, use that instead
    if (widget.dashboardStats['totalSales'] != null) {
      _totalSales = (widget.dashboardStats['totalSales'] as num).toDouble();
    }
  }

  void _changeChartType(ChartType type) {
    setState(() {
      _currentChartType = type;
      _animationController.reset();
      _animationController.forward();
    });
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
                  Row(
                    children: [
                      // Chart type selector
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildChartTypeButton(
                              ChartType.line,
                              'Line',
                              Icons.show_chart,
                            ),
                            _buildChartTypeButton(
                              ChartType.area,
                              'Area',
                              Icons.area_chart,
                            ),
                            _buildChartTypeButton(
                              ChartType.bar,
                              'Bar',
                              Icons.bar_chart,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  // Growth indicator
                  Row(
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
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return _buildChart();
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

  Widget _buildChartTypeButton(ChartType type, String tooltip, IconData icon) {
    final isSelected = _currentChartType == type;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _changeChartType(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primaryChartColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : widget.textSecondaryColor,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    switch (_currentChartType) {
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.area:
        return _buildAreaChart();
      case ChartType.line:
      default:
        return _buildLineChart();
    }
  }

  Widget _buildLineChart() {
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
            barWidth: 3,
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
                  _primaryChartColor.withOpacity(0.3),
                  _secondaryChartColor.withOpacity(0.0),
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
            barWidth: 3,
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
                  _primaryChartColor.withOpacity(0.4),
                  _primaryChartColor.withOpacity(0.1),
                  _secondaryChartColor.withOpacity(0.0),
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

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
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
        minY: 0,
        maxY: _calculateMaxY(_maxValue),
        barGroups: _salesData.map((data) {
          Color barColor = _primaryChartColor;

          // Highlight highest value
          if (data.index == _highestValueIndex) {
            barColor = _highlightColor;
          }

          // Highlight today's value
          if (data.index == _todayIndex) {
            barColor = _primaryChartColor;
          }

          return BarChartGroupData(
            x: data.index,
            barRods: [
              BarChartRodData(
                toY: data.value * _animation.value,
                gradient: LinearGradient(
                  colors: [
                    barColor,
                    barColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.white.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = _salesData[groupIndex];
              return BarTooltipItem(
                '${data.formattedDate} (${data.fullWeekday})\n',
                const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '₱${NumberFormat('#,##0.00').format(data.value)}',
                    style: TextStyle(
                      color: data.value > 0 ? _primaryChartColor : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
                        data.day,
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
                      const SizedBox(height: 1),
                      Text(
                        data.weekday,
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
}

// Helper class to store sales data points
class _SalesDataPoint {
  final String date;
  final double value;
  final String day;
  final String weekday;
  final String fullWeekday;
  final String formattedDate;
  final int index;

  _SalesDataPoint({
    required this.date,
    required this.value,
    required this.day,
    required this.weekday,
    required this.fullWeekday,
    required this.formattedDate,
    required this.index,
  });
}
