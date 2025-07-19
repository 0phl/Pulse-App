import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/barangay_profile.dart';
import '../../widgets/improved_kpi_card.dart';

class BarangayProfileDetailPage extends StatefulWidget {
  final BarangayProfile profile;

  const BarangayProfileDetailPage({
    super.key,
    required this.profile,
  });

  @override
  State<BarangayProfileDetailPage> createState() =>
      _BarangayProfileDetailPageState();
}

class _BarangayProfileDetailPageState extends State<BarangayProfileDetailPage> {
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.profile.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        actions: [
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isGeneratingPdf ? null : _generatePdfReport,
            tooltip: 'Generate PDF Report',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(isSmallScreen),
            const SizedBox(height: 24),
            _buildKpiCards(isSmallScreen),
            const SizedBox(height: 24),
            _buildChartsSection(isSmallScreen),
            const SizedBox(height: 24),
            _buildAdminContactInfo(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isSmallScreen ? 30 : 40,
                  backgroundColor: const Color(0xFFE6F7F2),
                  backgroundImage: widget.profile.adminAvatar != null
                      ? NetworkImage(widget.profile.adminAvatar!)
                      : null,
                  child: widget.profile.adminAvatar == null
                      ? Icon(
                          Icons.location_city,
                          color: const Color(0xFF00C49A),
                          size: isSmallScreen ? 30 : 40,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.name,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Barangay Captain: ${widget.profile.adminName}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusBadge(widget.profile.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('Location', widget.profile.fullAddress),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Date Registered',
              DateFormat('MMMM dd, yyyy').format(widget.profile.registeredAt),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Last Analytics Update',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(widget.profile.analytics.lastUpdated),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        displayText = 'Active';
        break;
      case 'pending':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        displayText = 'Pending';
        break;
      case 'inactive':
        backgroundColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        displayText = 'Inactive';
        break;
      default:
        backgroundColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildKpiCards(bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ImprovedKpiCard(
                  title: 'Total Users',
                  value:
                      widget.profile.analytics.totalRegisteredUsers.toString(),
                  subtitle: 'Registered',
                  icon: Icons.people,
                  color: const Color(0xFF00C49A),
                  trend: '+${widget.profile.analytics.thisMonthUserGrowth}',
                  isPositiveTrend:
                      widget.profile.analytics.thisMonthUserGrowth >= 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ImprovedKpiCard(
                  title: 'Active Users',
                  value: widget.profile.analytics.totalActiveUsers.toString(),
                  subtitle: 'Last 30 days',
                  icon: Icons.trending_up,
                  color: const Color(0xFF4A90E2),
                  trend:
                      '${widget.profile.analytics.activeUserPercentage.toStringAsFixed(1)}%',
                  isPositiveTrend:
                      widget.profile.analytics.activeUserPercentage > 50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ImprovedKpiCard(
                  title: 'Public Posts',
                  value: widget.profile.analytics.publicPostsCount.toString(),
                  subtitle: 'Announcements',
                  icon: Icons.campaign,
                  color: const Color(0xFFF5A623),
                  trend: '',
                  isPositiveTrend: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ImprovedKpiCard(
                  title: 'Reports',
                  value: widget.profile.analytics.reportsSubmitted.toString(),
                  subtitle: 'Submitted',
                  icon: Icons.report,
                  color: const Color(0xFFE74C3C),
                  trend: '',
                  isPositiveTrend: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ImprovedKpiCard(
            title: 'Volunteers',
            value: widget.profile.analytics.volunteerParticipants.toString(),
            subtitle:
                'This week: ${widget.profile.analytics.thisWeekVolunteers}',
            icon: Icons.volunteer_activism,
            color: const Color(0xFF9B59B6),
            trend: '+${widget.profile.analytics.thisWeekVolunteers}',
            isPositiveTrend: widget.profile.analytics.thisWeekVolunteers >= 0,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ImprovedKpiCard(
              title: 'Total Users',
              value: widget.profile.analytics.totalRegisteredUsers.toString(),
              subtitle: 'Registered',
              icon: Icons.people,
              color: const Color(0xFF00C49A),
              trend: '+${widget.profile.analytics.thisMonthUserGrowth}',
              isPositiveTrend:
                  widget.profile.analytics.thisMonthUserGrowth >= 0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ImprovedKpiCard(
              title: 'Active Users',
              value: widget.profile.analytics.totalActiveUsers.toString(),
              subtitle: 'Last 30 days',
              icon: Icons.trending_up,
              color: const Color(0xFF4A90E2),
              trend:
                  '${widget.profile.analytics.activeUserPercentage.toStringAsFixed(1)}%',
              isPositiveTrend:
                  widget.profile.analytics.activeUserPercentage > 50,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ImprovedKpiCard(
              title: 'Public Posts',
              value: widget.profile.analytics.publicPostsCount.toString(),
              subtitle: 'Announcements',
              icon: Icons.campaign,
              color: const Color(0xFFF5A623),
              trend: '',
              isPositiveTrend: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ImprovedKpiCard(
              title: 'Reports',
              value: widget.profile.analytics.reportsSubmitted.toString(),
              subtitle: 'Submitted',
              icon: Icons.report,
              color: const Color(0xFFE74C3C),
              trend: '',
              isPositiveTrend: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ImprovedKpiCard(
              title: 'Volunteers',
              value: widget.profile.analytics.volunteerParticipants.toString(),
              subtitle:
                  'This week: ${widget.profile.analytics.thisWeekVolunteers}',
              icon: Icons.volunteer_activism,
              color: const Color(0xFF9B59B6),
              trend: '+${widget.profile.analytics.thisWeekVolunteers}',
              isPositiveTrend: widget.profile.analytics.thisWeekVolunteers >= 0,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildChartsSection(bool isSmallScreen) {
    return Column(
      children: [
        if (isSmallScreen) ...[
          _buildUserGrowthChart(),
          const SizedBox(height: 24),
          _buildVolunteerChart(),
          const SizedBox(height: 24),
          _buildReportsCategoryChart(),
        ] else ...[
          Row(
            children: [
              Expanded(flex: 2, child: _buildUserGrowthChart()),
              const SizedBox(width: 24),
              Expanded(child: _buildReportsCategoryChart()),
            ],
          ),
          const SizedBox(height: 24),
          _buildVolunteerChart(),
        ],
      ],
    );
  }

  Widget _buildUserGrowthChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Growth (Last 12 Months)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final months = widget
                              .profile.analytics.monthlyUserGrowth.keys
                              .toList()
                            ..sort();
                          if (value.toInt() >= 0 &&
                              value.toInt() < months.length) {
                            final monthKey = months[value.toInt()];
                            final parts = monthKey.split('-');
                            if (parts.length == 2) {
                              final month = int.parse(parts[1]);
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  DateFormat('MMM')
                                      .format(DateTime(2024, month)),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  minX: 0,
                  maxX: (widget.profile.analytics.monthlyUserGrowth.length - 1)
                      .toDouble(),
                  minY: 0,
                  maxY: _getMaxUserGrowth(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getUserGrowthSpots(),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C49A), Color(0xFF4A90E2)],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00C49A).withOpacity(0.3),
                            const Color(0xFF4A90E2).withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Volunteer Participation (Last 8 Weeks)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxVolunteers(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                      tooltipMargin: -10,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.round()} volunteers',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final weeks = widget
                              .profile.analytics.weeklyVolunteers.keys
                              .toList()
                            ..sort();
                          if (value.toInt() >= 0 &&
                              value.toInt() < weeks.length) {
                            final weekKey = weeks[value.toInt()];
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                weekKey.split('-W')[1],
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 5,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  barGroups: _getVolunteerBarGroups(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsCategoryChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports by Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: widget.profile.analytics.categoryReports.isEmpty
                  ? const Center(
                      child: Text(
                        'No reports data available',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback:
                                  (FlTouchEvent event, pieTouchResponse) {},
                              enabled: true,
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 3,
                            centerSpaceRadius: 55,
                            sections: _getReportsSections(),
                          ),
                        ),
                        // Center text showing total reports
                        Positioned.fill(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.profile.analytics.reportsSubmitted}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const Text(
                                  'Total Reports',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (widget.profile.analytics.categoryReports.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildReportsLegend(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportsLegend() {
    final categories =
        widget.profile.analytics.categoryReports.entries.toList();
    final total = categories.fold(0, (sum, entry) => sum + entry.value);

    if (total == 0) return const SizedBox.shrink();

    // Sort categories by value (descending)
    categories.sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFE74C3C),
      const Color(0xFFF5A623),
      const Color(0xFF00C49A),
      const Color(0xFF4A90E2),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
      const Color(0xFF3498DB),
      const Color(0xFFE67E22),
    ];

    // Group small categories together (less than 5% of total)
    final mainCategories = <MapEntry<String, int>>[];
    int othersTotal = 0;

    for (final category in categories) {
      final percentage = (category.value / total) * 100;
      if (percentage >= 5.0 && mainCategories.length < 6) {
        mainCategories.add(category);
      } else {
        othersTotal += category.value;
      }
    }

    final legendItems = <MapEntry<String, int>>[];
    legendItems.addAll(mainCategories);
    if (othersTotal > 0) {
      legendItems.add(MapEntry('Others', othersTotal));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: legendItems.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final percentage = (category.value / total) * 100;

          return Padding(
            padding:
                EdgeInsets.only(bottom: index < legendItems.length - 1 ? 8 : 0),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.key,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${category.value}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors[index % colors.length].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors[index % colors.length],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdminContactInfo(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Contact Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            _buildContactRow(Icons.person, 'Name', widget.profile.adminName),
            if (widget.profile.adminEmail != null) ...[
              const SizedBox(height: 12),
              _buildContactRow(
                  Icons.email, 'Email', widget.profile.adminEmail!),
            ],
            if (widget.profile.adminPhone != null) ...[
              const SizedBox(height: 12),
              _buildContactRow(
                  Icons.phone, 'Phone', widget.profile.adminPhone!),
            ],
            const SizedBox(height: 12),
            _buildContactRow(
                Icons.location_on, 'Barangay', widget.profile.name),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF00C49A),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Chart data helper methods
  List<FlSpot> _getUserGrowthSpots() {
    final months = widget.profile.analytics.monthlyUserGrowth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return months.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
    }).toList();
  }

  double _getMaxUserGrowth() {
    if (widget.profile.analytics.monthlyUserGrowth.isEmpty) return 10;
    final maxValue = widget.profile.analytics.monthlyUserGrowth.values
        .reduce((a, b) => a > b ? a : b);
    return (maxValue + 5).toDouble();
  }

  List<BarChartGroupData> _getVolunteerBarGroups() {
    final weeks = widget.profile.analytics.weeklyVolunteers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return weeks.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: const Color(0xFF9B59B6),
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxVolunteers() {
    if (widget.profile.analytics.weeklyVolunteers.isEmpty) return 10;
    final maxValue = widget.profile.analytics.weeklyVolunteers.values
        .reduce((a, b) => a > b ? a : b);
    return (maxValue + 5).toDouble();
  }

  List<PieChartSectionData> _getReportsSections() {
    final categories =
        widget.profile.analytics.categoryReports.entries.toList();
    final total = categories.fold(0, (sum, entry) => sum + entry.value);

    if (total == 0) return [];

    // Sort categories by value (descending)
    categories.sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFE74C3C),
      const Color(0xFFF5A623),
      const Color(0xFF00C49A),
      const Color(0xFF4A90E2),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
      const Color(0xFF3498DB),
      const Color(0xFFE67E22),
    ];

    // Group small categories together (less than 5% of total)
    final mainCategories = <MapEntry<String, int>>[];
    int othersTotal = 0;

    for (final category in categories) {
      final percentage = (category.value / total) * 100;
      if (percentage >= 5.0 && mainCategories.length < 6) {
        mainCategories.add(category);
      } else {
        othersTotal += category.value;
      }
    }

    final sectionsToShow = <MapEntry<String, int>>[];
    sectionsToShow.addAll(mainCategories);
    if (othersTotal > 0) {
      sectionsToShow.add(MapEntry('Others', othersTotal));
    }

    return sectionsToShow.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final percentage = (category.value / total) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: category.value.toDouble(),
        title: percentage >= 8.0 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(0.5, 0.5),
              blurRadius: 1.0,
              color: Colors.black26,
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _generatePdfReport() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildPdfHeader(),
              pw.SizedBox(height: 20),
              _buildPdfProfileInfo(),
              pw.SizedBox(height: 20),
              _buildPdfAnalytics(),
              pw.SizedBox(height: 20),
              _buildPdfContactInfo(),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Barangay_Profile_${widget.profile.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Barangay Profile Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            widget.profile.name,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfProfileInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Profile Information',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildPdfInfoRow('Barangay Name', widget.profile.name),
          _buildPdfInfoRow('Admin/Captain', widget.profile.adminName),
          _buildPdfInfoRow('Location', widget.profile.fullAddress),
          _buildPdfInfoRow('Status', widget.profile.status.toUpperCase()),
          _buildPdfInfoRow('Date Registered',
              DateFormat('MMMM dd, yyyy').format(widget.profile.registeredAt)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfAnalytics() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Analytics Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfStatCard('Total Registered Users',
                    widget.profile.analytics.totalRegisteredUsers.toString()),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildPdfStatCard('Active Users (30 days)',
                    widget.profile.analytics.totalActiveUsers.toString()),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfStatCard('Public Posts/Announcements',
                    widget.profile.analytics.publicPostsCount.toString()),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildPdfStatCard('Reports Submitted',
                    widget.profile.analytics.reportsSubmitted.toString()),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfStatCard('Volunteer Participants',
                    widget.profile.analytics.volunteerParticipants.toString()),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _buildPdfStatCard('This Week Volunteers',
                    widget.profile.analytics.thisWeekVolunteers.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfContactInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Contact Information',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildPdfInfoRow('Admin Name', widget.profile.adminName),
          if (widget.profile.adminEmail != null)
            _buildPdfInfoRow('Email', widget.profile.adminEmail!),
          if (widget.profile.adminPhone != null)
            _buildPdfInfoRow('Phone', widget.profile.adminPhone!),
        ],
      ),
    );
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }
}
