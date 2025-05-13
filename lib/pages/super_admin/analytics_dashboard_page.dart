import 'package:flutter/material.dart';
import '../../services/super_admin_service.dart';
import '../../widgets/improved_kpi_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Import web implementation for web platform
import 'package:printing/printing_web.dart'
    if (dart.library.io) 'package:printing/printing.dart';

class SuperAdminAnalyticsDashboardPage extends StatefulWidget {
  const SuperAdminAnalyticsDashboardPage({super.key});

  @override
  State<SuperAdminAnalyticsDashboardPage> createState() =>
      _SuperAdminAnalyticsDashboardPageState();
}

class _SuperAdminAnalyticsDashboardPageState
    extends State<SuperAdminAnalyticsDashboardPage> {
  final SuperAdminService _superAdminService = SuperAdminService();
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  String _selectedTimeRange = 'Last 30 Days';
  final List<String> _timeRanges = [
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days'
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get analytics data from the service
      final data =
          await _superAdminService.getAnalyticsData(_selectedTimeRange);

      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics data: $e')),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Create PDF document
      final pdf = pw.Document();

      // Define theme colors
      final PdfColor primaryColor =
          PdfColor.fromHex('00C49A'); // Match app brand color
      final PdfColor accentColor = PdfColor.fromHex('4A90E2');
      final PdfColor textColor = PdfColor.fromHex('2D3748');
      final PdfColor lightGrey = PdfColor.fromHex('F7F7F7');

      // Get current date
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      // Add formatted pages
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: lightGrey, width: 2))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PULSE',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      pw.Text(
                        'Analytics Report',
                        style: pw.TextStyle(
                          color: textColor,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Generated: $dateStr',
                    style: pw.TextStyle(
                      color: textColor.shade(50),
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  color: textColor.shade(50),
                  fontSize: 12,
                ),
              ),
            );
          },
          build: (pw.Context context) => [
            // Period Info
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Report Period: $_selectedTimeRange',
                    style: pw.TextStyle(
                      color: textColor,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Summary Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Analytics Summary',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      _buildSummaryCard(
                        'Total Communities',
                        _analyticsData['totalCommunities']?.toString() ?? '0',
                        _analyticsData['communityGrowth']?.toString() ?? '0%',
                        primaryColor,
                        lightGrey,
                        textColor,
                      ),
                      pw.SizedBox(width: 15),
                      _buildSummaryCard(
                        'Total Admins',
                        _analyticsData['totalAdmins']?.toString() ?? '0',
                        _analyticsData['adminGrowth']?.toString() ?? '0%',
                        accentColor,
                        lightGrey,
                        textColor,
                      ),
                      pw.SizedBox(width: 15),
                      _buildSummaryCard(
                        'Pending Applications',
                        _analyticsData['pendingApplications']?.toString() ??
                            '0',
                        _analyticsData['applicationGrowth']?.toString() ?? '0%',
                        PdfColor.fromHex('F5A623'),
                        lightGrey,
                        textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top Communities Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Top Active Communities',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildCommunitiesTable(
                    (_analyticsData['topActiveCommunities'] as List?) ?? [],
                    primaryColor,
                    lightGrey,
                    textColor,
                  ),
                ],
              ),
            ),

            // Regional Distribution Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Regional Distribution',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildRegionalDistributionTable(
                    (_analyticsData['communityByRegion']
                            as Map<String, dynamic>?) ??
                        {},
                    primaryColor,
                    lightGrey,
                    textColor,
                  ),
                ],
              ),
            ),

            // Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'This report is automatically generated from the PULSE analytics system. The data represents activity within the selected time period.',
                style: pw.TextStyle(
                  color: textColor.shade(50),
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );

      // Generate and display PDF
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: 'PULSE_Analytics_Report',
      );

      _showSuccessMessage();
    } catch (e) {
      // Log error
      debugPrint('Error generating PDF report: $e');
      _showErrorMessage('Error generating report: $e');
    } finally {
      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper widget for PDF report - Summary Card
  pw.Widget _buildSummaryCard(
    String title,
    String value,
    String growth,
    PdfColor color,
    PdfColor bgColor,
    PdfColor textColor,
  ) {
    // Format growth with sign
    String formattedGrowth = growth;
    if (!growth.startsWith('+') && !growth.startsWith('-') && growth != '0%') {
      formattedGrowth = '+$growth';
    }

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(5),
          border: pw.Border.all(color: color.shade(50), width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Growth: $formattedGrowth',
              style: pw.TextStyle(
                color: textColor.shade(50),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for PDF report - Communities Table
  pw.Widget _buildCommunitiesTable(
    List communities,
    PdfColor color,
    PdfColor bgColor,
    PdfColor textColor,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: color.shade(20), width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: [
            _buildPdfTableCell('Community Name', textColor, true, 1),
            _buildPdfTableCell('Members', textColor, true, 2),
            _buildPdfTableCell('Engagement', textColor, true, 2),
          ],
        ),
        // Data rows
        ...communities
            .map((community) => pw.TableRow(
                  children: [
                    _buildPdfTableCell(community['name'], textColor, false, 1),
                    _buildPdfTableCell(
                        community['members'].toString(), textColor, false, 2),
                    _buildPdfTableCell(
                        '${community['engagement']}%', textColor, false, 2),
                  ],
                ))
            .toList(),
      ],
    );
  }

  // Helper widget for PDF report - Regional Distribution Table
  pw.Widget _buildRegionalDistributionTable(
    Map<String, dynamic> regions,
    PdfColor color,
    PdfColor bgColor,
    PdfColor textColor,
  ) {
    // Calculate total communities
    final int total =
        regions.values.fold<int>(0, (sum, value) => sum + (value as int));

    // Create table rows
    List<pw.TableRow> rows = [
      // Header row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: [
          _buildPdfTableCell('Region', textColor, true, 1),
          _buildPdfTableCell('Communities', textColor, true, 2),
          _buildPdfTableCell('Percentage', textColor, true, 2),
        ],
      ),
    ];

    // Add data rows for each region
    regions.forEach((region, count) {
      final percentage =
          total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
      rows.add(pw.TableRow(
        children: [
          _buildPdfTableCell(region, textColor, false, 1),
          _buildPdfTableCell(count.toString(), textColor, false, 2),
          _buildPdfTableCell('$percentage%', textColor, false, 2),
        ],
      ));
    });

    return pw.Table(
      border: pw.TableBorder.all(color: color.shade(20), width: 0.5),
      children: rows,
    );
  }

  // Helper for PDF table cells
  pw.Widget _buildPdfTableCell(
    String text,
    PdfColor textColor,
    bool isHeader,
    int alignment, // 1=left, 2=center, 3=right
  ) {
    pw.TextAlign textAlign = pw.TextAlign.left;
    if (alignment == 2) textAlign = pw.TextAlign.center;
    if (alignment == 3) textAlign = pw.TextAlign.right;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: textAlign,
        style: pw.TextStyle(
          color: textColor,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  void _showSuccessMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Color(0xFF00C49A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                _buildTimeRangeDropdown(),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(isSmallScreen ? 'PDF' : 'Generate Report'),
                  onPressed: _generatePdfReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C49A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiCards(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildCharts(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildTopCommunitiesTable(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeRange,
          items: _timeRanges.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                ),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTimeRange = newValue;
              });
              _loadAnalyticsData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildKpiCards(bool isSmallScreen) {
    // Format growth percentages with proper sign and decimal places
    String formatGrowth(double value) {
      // Ensure the value is rounded to 1 decimal place to avoid floating point precision issues
      final roundedValue = double.parse(value.toStringAsFixed(1));
      final sign = roundedValue >= 0 ? '+' : '';
      return '$sign${roundedValue.toStringAsFixed(1)}%';
    }

    if (isSmallScreen) {
      return Column(
        children: [
          ImprovedKpiCard(
            title: 'Total Communities',
            value: _analyticsData['totalCommunities'].toString(),
            subtitle: 'New: ${_analyticsData['newCommunitiesInPeriod'] ?? 0}',
            icon: Icons.location_city,
            color: const Color(0xFF00C49A),
            trend: formatGrowth(_analyticsData['communityGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['communityGrowth'] ?? 0) >= 0,
          ),
          const SizedBox(height: 12),
          ImprovedKpiCard(
            title: 'Total Admins',
            value: _analyticsData['totalAdmins'].toString(),
            subtitle: 'New: ${_analyticsData['newAdminsThisWeek'] ?? 0}',
            icon: Icons.admin_panel_settings,
            color: const Color(0xFF4A90E2),
            trend: formatGrowth(_analyticsData['adminGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['adminGrowth'] ?? 0) >= 0,
          ),
          const SizedBox(height: 12),
          ImprovedKpiCard(
            title: 'Pending Applications',
            value: _analyticsData['pendingApplications'].toString(),
            subtitle: 'New: ${_analyticsData['newApplicationsThisWeek'] ?? 0}',
            icon: Icons.pending_actions,
            color: const Color(0xFFF5A623),
            trend: formatGrowth(_analyticsData['applicationGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['applicationGrowth'] ?? 0) >= 0,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ImprovedKpiCard(
            title: 'Total Communities',
            value: _analyticsData['totalCommunities'].toString(),
            subtitle: 'New: ${_analyticsData['newCommunitiesInPeriod'] ?? 0}',
            icon: Icons.location_city,
            color: const Color(0xFF00C49A),
            trend: formatGrowth(_analyticsData['communityGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['communityGrowth'] ?? 0) >= 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ImprovedKpiCard(
            title: 'Total Admins',
            value: _analyticsData['totalAdmins'].toString(),
            subtitle: 'New: ${_analyticsData['newAdminsThisWeek'] ?? 0}',
            icon: Icons.admin_panel_settings,
            color: const Color(0xFF4A90E2),
            trend: formatGrowth(_analyticsData['adminGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['adminGrowth'] ?? 0) >= 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ImprovedKpiCard(
            title: 'Pending Applications',
            value: _analyticsData['pendingApplications'].toString(),
            subtitle: 'New: ${_analyticsData['newApplicationsThisWeek'] ?? 0}',
            icon: Icons.pending_actions,
            color: const Color(0xFFF5A623),
            trend: formatGrowth(_analyticsData['applicationGrowth'] ?? 0),
            isPositiveTrend: (_analyticsData['applicationGrowth'] ?? 0) >= 0,
          ),
        ),
      ],
    );
  }

  Widget _buildCharts(bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          _buildTrendChart(),
          const SizedBox(height: 24),
          _buildRegionDistributionChart(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildTrendChart(),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildRegionDistributionChart(),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Growth Trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
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
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value % 2 != 0) return const SizedBox();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              'M${value.toInt() + 1}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 40,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      left: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  minX: 0,
                  maxX: 9,
                  minY: 0,
                  maxY: 160,
                  lineBarsData: [
                    _createLineChartBarData(
                      _analyticsData['communityTrend'],
                      const Color(0xFF00C49A),
                    ),
                    _createLineChartBarData(
                      _analyticsData['adminTrend'],
                      const Color(0xFF4A90E2),
                    ),
                    _createLineChartBarData(
                      _analyticsData['applicationTrend'],
                      const Color(0xFFF5A623),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Communities', const Color(0xFF00C49A)),
                const SizedBox(width: 24),
                _buildLegendItem('Admins', const Color(0xFF4A90E2)),
                const SizedBox(width: 24),
                _buildLegendItem('Applications', const Color(0xFFF5A623)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _createLineChartBarData(List<dynamic> data, Color color) {
    return LineChartBarData(
      spots: List.generate(
        data.length,
        (index) => FlSpot(index.toDouble(), data[index].toDouble()),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(25), // 10% opacity
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRegionDistributionChart() {
    final regions = _analyticsData['communityByRegion'] as Map<String, dynamic>;
    // Use totalCommunities instead of calculating from regions to ensure consistency
    final total = _analyticsData['totalCommunities'] as int;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communities by Region',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _createPieChartSections(regions, total),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildPieChartLegend(regions),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _createPieChartSections(
      Map<String, dynamic> regions, int total) {
    // Define colors for regions
    final Map<String, Color> regionColors = {
      'Region I': const Color(0xFF00C49A),
      'Region II': const Color(0xFF4A90E2),
      'Region III': const Color(0xFFF5A623),
      'Region IV-A': const Color(0xFFFF6B6B),
      'Region IV-B': const Color(0xFF9B59B6),
      'Region V': const Color(0xFF3498DB),
      'Region VI': const Color(0xFF2ECC71),
      'Region VII': const Color(0xFFE74C3C),
      'Region VIII': const Color(0xFFF1C40F),
      'Region IX': const Color(0xFF1ABC9C),
      'Region X': const Color(0xFFD35400),
      'Region XI': const Color(0xFF8E44AD),
      'Region XII': const Color(0xFF27AE60),
      'NCR': const Color(0xFFE67E22),
      'CAR': const Color(0xFF16A085),
      'BARMM': const Color(0xFFC0392B),
      'CARAGA': const Color(0xFF2980B9),
      'Other': Colors.grey,
    };

    // Filter out regions with zero values
    final nonZeroRegions =
        regions.entries.where((entry) => entry.value > 0).toList();

    // If there are no non-zero regions, return an empty section
    if (nonZeroRegions.isEmpty || total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: 'No Data',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
      ];
    }

    // Create sections for non-zero regions
    return nonZeroRegions.map((entry) {
      final regionName = entry.key;
      final value = entry.value as int;
      final percentage = (value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: regionColors[regionName] ?? Colors.grey,
        // Use value for the size of the pie slice
        value: value.toDouble(),
        // Show percentage based on total communities
        title: '$percentage%',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildPieChartLegend(Map<String, dynamic> regions) {
    // Define colors for regions (same as in _createPieChartSections)
    final Map<String, Color> regionColors = {
      'Region I': const Color(0xFF00C49A),
      'Region II': const Color(0xFF4A90E2),
      'Region III': const Color(0xFFF5A623),
      'Region IV-A': const Color(0xFFFF6B6B),
      'Region IV-B': const Color(0xFF9B59B6),
      'Region V': const Color(0xFF3498DB),
      'Region VI': const Color(0xFF2ECC71),
      'Region VII': const Color(0xFFE74C3C),
      'Region VIII': const Color(0xFFF1C40F),
      'Region IX': const Color(0xFF1ABC9C),
      'Region X': const Color(0xFFD35400),
      'Region XI': const Color(0xFF8E44AD),
      'Region XII': const Color(0xFF27AE60),
      'NCR': const Color(0xFFE67E22),
      'CAR': const Color(0xFF16A085),
      'BARMM': const Color(0xFFC0392B),
      'CARAGA': const Color(0xFF2980B9),
      'Other': Colors.grey,
    };

    // Use totalCommunities for consistent percentage calculation
    final totalCommunities = _analyticsData['totalCommunities'] as int;

    // Filter out regions with zero values
    final nonZeroRegions =
        regions.entries.where((entry) => entry.value > 0).toList();

    // If there are no non-zero regions, show a message
    if (nonZeroRegions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'No active communities found',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Create a grid of legend items
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16.0,
      runSpacing: 8.0,
      children: nonZeroRegions.map((entry) {
        final regionName = entry.key;
        final value = entry.value as int;
        // Calculate percentage based on total communities
        final percentage = totalCommunities > 0
            ? (value / totalCommunities * 100).toStringAsFixed(1)
            : '0.0';

        return _buildPieLegendItem(
            regionName, regionColors[regionName] ?? Colors.grey, value, percentage);
      }).toList(),
    );
  }

  Widget _buildPieLegendItem(String label, Color color, int value, String percentage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($value) - $percentage%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCommunitiesTable() {
    final communities = _analyticsData['topActiveCommunities'] as List;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Active Communities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  children: [
                    _buildTableHeaderCell('Community Name'),
                    _buildTableHeaderCell('Members'),
                    _buildTableHeaderCell('Engagement'),
                  ],
                ),
                ...communities.map((community) => TableRow(
                      children: [
                        _buildTableCell(community['name']),
                        _buildTableCell(community['members'].toString()),
                        _buildTableCell('${community['engagement']}%'),
                      ],
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}
