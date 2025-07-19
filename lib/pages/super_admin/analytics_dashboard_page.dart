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
import 'dart:async';

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
  String _selectedTimeRange = 'Last 7 Days';
  final List<String> _timeRanges = [
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
    'Last Year'
  ];
  StreamSubscription<Map<String, dynamic>>? _analyticsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToAnalyticsData();
  }

  @override
  void dispose() {
    _analyticsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToAnalyticsData() {
    // Cancel any existing subscription
    _analyticsSubscription?.cancel();

    setState(() {
      _isLoading = true;
    });

    // Subscribe to analytics data stream
    _analyticsSubscription =
        _superAdminService.getAnalyticsDataStream(_selectedTimeRange).listen(
      (data) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading analytics data: $error')),
          );
        }
      },
    );
  }

  // This method is now used only when manually refreshing the data
  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
      setState(() {
        _isLoading = true;
      });

      final pdf = pw.Document();

      // Define theme colors
      final PdfColor primaryColor =
          PdfColor.fromHex('00C49A'); // Match app brand color
      final PdfColor accentColor = PdfColor.fromHex('4A90E2');
      final PdfColor textColor = PdfColor.fromHex('2D3748');
      final PdfColor lightGrey = PdfColor.fromHex('F7F7F7');
      final PdfColor warningColor = PdfColor.fromHex('F5A623');
      final PdfColor successColor = PdfColor.fromHex('4CAF50');
      final PdfColor dangerColor = PdfColor.fromHex('F44336');

      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

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

            // Executive Summary
            _buildExecutiveSummarySection(primaryColor, textColor, lightGrey),

            // KPI Summary Cards
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Performance Metrics',
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
                        'Communities',
                        _analyticsData['totalCommunities']?.toString() ?? '0',
                        _formatGrowth(_analyticsData['communityGrowth']),
                        _getGrowthColor(
                            _analyticsData['communityGrowth'], primaryColor),
                        lightGrey,
                        textColor,
                      ),
                      pw.SizedBox(width: 15),
                      _buildSummaryCard(
                        'Total Admins',
                        _analyticsData['totalAdmins']?.toString() ?? '0',
                        _formatGrowth(_analyticsData['adminGrowth']),
                        _getGrowthColor(
                            _analyticsData['adminGrowth'], accentColor),
                        lightGrey,
                        textColor,
                      ),
                      pw.SizedBox(width: 15),
                      _buildSummaryCard(
                        'Applications',
                        _analyticsData['pendingApplications']?.toString() ??
                            '0',
                        _formatGrowth(_analyticsData['applicationGrowth']),
                        _getGrowthColor(
                            _analyticsData['applicationGrowth'], warningColor),
                        lightGrey,
                        textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Growth Trend Chart
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Community Growth Trend',
                    style: pw.TextStyle(
                      color: primaryColor,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfTrendChart(primaryColor, lightGrey, textColor),
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
                    _getFilteredRegionData(),
                    primaryColor,
                    lightGrey,
                    textColor,
                  ),
                ],
              ),
            ),

            // Top Active Communities Section
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
                    _getFilteredCommunitiesData(),
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
                'This report is automatically generated from the PULSE analytics system. The data represents activity within the selected time period. For questions or detailed analysis, please contact support.',
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

  // Helper methods for PDF report generation
  String _buildExecutiveSummary() {
    final communities = _analyticsData['totalCommunities'] ?? 0;
    final admins = _analyticsData['totalAdmins'] ?? 0;
    final applications = _analyticsData['pendingApplications'] ?? 0;
    final users = _analyticsData['totalUsers'] ?? 0;
    final communityGrowth = _analyticsData['communityGrowth'] ?? 0.0;
    final growthText = communityGrowth >= 0 ? 'growth' : 'decline';

    String summary =
        'In the $_selectedTimeRange period, the platform has maintained $communities active communities with $admins administrators serving approximately $users users. ';

    if (communityGrowth != 0) {
      summary +=
          'We observed a ${communityGrowth.abs().toStringAsFixed(1)}% $growthText in community count. ';
    } else {
      summary += 'Community count has remained stable. ';
    }

    if (applications > 0) {
      summary +=
          'There are currently $applications pending applications awaiting review. ';
    }

    final topRegions = _getTopRegions();
    if (topRegions.isNotEmpty) {
      summary += 'The most active regions are ${topRegions.join(', ')}. ';
    }

    final avgEngagement = _analyticsData['userEngagementRate'] ?? 0.0;
    if (avgEngagement > 0) {
      summary +=
          'Average user engagement across communities is ${avgEngagement.toStringAsFixed(1)}%. ';
    }

    return summary;
  }

  List<String> _getTopRegions() {
    final regionData =
        _analyticsData['communityByRegion'] as Map<String, dynamic>?;
    if (regionData == null) return [];

    // Convert to list of entries, sort by count, and take top 3
    final sortedRegions = regionData.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return sortedRegions
        .where((entry) => entry.value > 0)
        .take(3)
        .map((entry) => entry.key)
        .toList();
  }

  Map<String, dynamic> _getFilteredRegionData() {
    final regionData =
        _analyticsData['communityByRegion'] as Map<String, dynamic>?;
    if (regionData == null) return {};

    // Filter out regions with 0 communities for cleaner report
    return Map.fromEntries(
        regionData.entries.where((entry) => entry.value > 0));
  }

  List<Map<String, dynamic>> _getFilteredCommunitiesData() {
    final communities =
        _analyticsData['topActiveCommunities'] as List<dynamic>?;
    if (communities == null) return [];

    // Filter to only include communities with at least 1 member or engagement > 0
    return communities
        .where((community) =>
            (community['members'] as int) > 0 ||
            (community['engagement'] as int) > 0)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  String _formatGrowth(dynamic growthValue) {
    if (growthValue == null) return '0%';

    final growth = growthValue is double ? growthValue : 0.0;
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(1)}%';
  }

  PdfColor _getGrowthColor(dynamic growthValue, PdfColor defaultColor) {
    if (growthValue == null) return defaultColor;

    final growth = growthValue is double ? growthValue : 0.0;
    if (growth > 0) return PdfColor.fromHex('4CAF50'); // Green for positive
    if (growth < 0) return PdfColor.fromHex('F44336'); // Red for negative
    return defaultColor; // Default color for zero
  }

  pw.Widget _buildRecommendationPoint(
      String title, String description, PdfColor textColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: textColor,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            description,
            style: pw.TextStyle(
              color: textColor.shade(80),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTrendChart(
      PdfColor color, PdfColor bgColor, PdfColor textColor) {
    final data = _analyticsData['communityTrend'] as List<dynamic>?;
    if (data == null || data.isEmpty) {
      return pw.Container(
        height: 100,
        alignment: pw.Alignment.center,
        child: pw.Text('No trend data available'),
      );
    }

    final currentTotal = _analyticsData['totalCommunities'] ?? 0;
    final growth = _analyticsData['communityGrowth'] ?? 0.0;
    final growthFormatted = _formatGrowth(_analyticsData['communityGrowth']);
    final direction = growth >= 0 ? 'increase' : 'decrease';

    final totalUsers = _analyticsData['totalUsers'] ?? 0;
    final userGrowth = _analyticsData['userGrowth'] ?? 0.0;
    final newUsers = totalUsers -
        (data.isNotEmpty ? data.first : 0) *
            15; // Estimate if not directly available

    final newCommunities = _analyticsData['newCommunitiesInPeriod'] ?? 0;

    final avgEngagement = _analyticsData['userEngagementRate'] ?? 0.0;

    // Define explicit colors for backgrounds
    final lightBgColor = PdfColors.white;
    final panelBgColor = PdfColor.fromHex('F5F7FA'); // Light gray background
    final separatorColor =
        PdfColor.fromHex('E1E5EA'); // Medium gray for separators

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: separatorColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Community Growth Summary',
            style: pw.TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),

          // Communities section
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: panelBgColor,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: separatorColor, width: 0.5),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Communities',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: textColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Current: $currentTotal ($growthFormatted)',
                        style: pw.TextStyle(fontSize: 10, color: textColor),
                      ),
                      if (newCommunities > 0) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'New this period: $newCommunities',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('4CAF50'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Separator
                pw.Container(
                  height: 40,
                  width: 1,
                  color: separatorColor,
                ),

                // Users section
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Users',
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: textColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Total: $totalUsers',
                          style: pw.TextStyle(fontSize: 10, color: textColor),
                        ),
                        if (newUsers > 0) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Estimated new: ${newUsers.toInt()}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColor.fromHex('4CAF50'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // Performance metrics
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: panelBgColor,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: separatorColor, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Performance Metrics',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: textColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Avg. Engagement:',
                            style: pw.TextStyle(fontSize: 10, color: textColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${avgEngagement.toStringAsFixed(1)}%',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: avgEngagement > 50.0
                                  ? PdfColor.fromHex('4CAF50')
                                  : avgEngagement > 25.0
                                      ? PdfColor.fromHex('FF9800')
                                      : PdfColor.fromHex('F44336'),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Growth Rate:',
                            style: pw.TextStyle(fontSize: 10, color: textColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '$growthFormatted ($direction)',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: _getGrowthColor(
                                  _analyticsData['communityGrowth'], textColor),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // Period comparison
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: panelBgColor,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: separatorColor, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Period Comparison',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: textColor,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Start of Period:',
                          style: pw.TextStyle(fontSize: 10, color: textColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${data.isNotEmpty ? data.first : 0} communities',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Current:',
                          style: pw.TextStyle(fontSize: 10, color: textColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '$currentTotal communities',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: textColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                // Simple progress indicator line
                pw.Container(
                  height: 4,
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Stack(children: [
                    // Background line
                    pw.Container(
                      height: 4,
                      decoration: pw.BoxDecoration(
                        color: separatorColor,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    // Progress indicator
                    pw.Container(
                      width: growth > 0 ? 120 : 50, // Width based on growth
                      height: 4,
                      decoration: pw.BoxDecoration(
                        color: growth >= 0
                            ? PdfColor.fromHex('4CAF50')
                            : PdfColor.fromHex('F44336'),
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),
          pw.Text(
            _getTimeRangeLabel(),
            style: pw.TextStyle(
              fontSize: 9,
              color: textColor.shade(70),
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeRangeLabel() {
    switch (_selectedTimeRange) {
      case 'Last 7 Days':
        return 'Data shown for the past week';
      case 'Last 30 Days':
        return 'Data shown for the past month';
      case 'Last 90 Days':
        return 'Data shown for the past quarter';
      case 'Last Year':
        return 'Data shown for the past year';
      default:
        return 'Data shown for the selected period';
    }
  }

  pw.Widget _buildPdfPieChart(
      PdfColor color, PdfColor bgColor, PdfColor textColor) {
    final regionData = _getFilteredRegionData();
    if (regionData.isEmpty) {
      return pw.Container(
        height: 150,
        alignment: pw.Alignment.center,
        child: pw.Text('No regional data available'),
      );
    }

    final entries = regionData.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    // Take top 5 regions
    final topRegions = entries.take(5).toList();

    final total =
        regionData.values.fold<int>(0, (sum, value) => sum + (value as int));

    // Define chart colors - using lighter colors
    final List<PdfColor> pieColors = [
      PdfColor.fromHex('00C49A'), // Primary
      PdfColor.fromHex('4A90E2'), // Blue
      PdfColor.fromHex('F5A623'), // Orange
      PdfColor.fromHex('FF6B6B'), // Red
      PdfColor.fromHex('9B59B6'), // Purple
    ];

    // Define header background color
    final headerBgColor = PdfColor.fromHex('F5F7FA'); // Light gray for header

    return pw.Container(
      height: 200,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color.shade(20), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Regional Distribution',
            style: pw.TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Table(
              border: pw.TableBorder.all(color: color.shade(20), width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _buildPdfTableCell('Region', textColor, true, 1),
                    _buildPdfTableCell('Count', textColor, true, 2),
                    _buildPdfTableCell('Percentage', textColor, true, 2),
                  ],
                ),
                ...topRegions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final region = entry.value;
                  final regionName = region.key;
                  final count = region.value;
                  final percentage = total > 0
                      ? (count / total * 100).toStringAsFixed(1)
                      : '0.0';

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                    ),
                    children: [
                      _buildPdfTableCell(regionName, textColor, false, 1),
                      _buildPdfTableCell(count.toString(), textColor, false, 2),
                      _buildPdfTableCell('$percentage%', textColor, false, 2),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
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
    // Define header background color
    final headerBgColor = PdfColor.fromHex('F5F7FA'); // Light gray for header

    return pw.Table(
      border: pw.TableBorder.all(color: color.shade(20), width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBgColor),
          children: [
            _buildPdfTableCell('Community Name', textColor, true, 1),
            _buildPdfTableCell('Members', textColor, true, 2),
            _buildPdfTableCell('Engagement', textColor, true, 2),
          ],
        ),
        // Data rows
        ...communities
            .map((community) => pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.white),
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

  // Helper widget for PDF report - Regional Distribution Table
  pw.Widget _buildRegionalDistributionTable(
    Map<String, dynamic> regions,
    PdfColor color,
    PdfColor bgColor,
    PdfColor textColor,
  ) {
    final int total =
        regions.values.fold<int>(0, (sum, value) => sum + (value as int));

    // Define light background color for all rows
    final headerBgColor = PdfColor.fromHex('F5F7FA'); // Light gray for header

    List<pw.TableRow> rows = [
      // Header row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerBgColor),
        children: [
          _buildPdfTableCell('Region', textColor, true, 1),
          _buildPdfTableCell('Communities', textColor, true, 2),
          _buildPdfTableCell('Percentage', textColor, true, 2),
        ],
      ),
    ];

    regions.forEach((region, count) {
      final percentage =
          total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.white),
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

  // Executive Summary Section
  pw.Container _buildExecutiveSummarySection(
      PdfColor primaryColor, PdfColor textColor, PdfColor lightGrey) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Executive Summary',
            style: pw.TextStyle(
              color: primaryColor,
              fontWeight: pw.FontWeight.bold,
              fontSize: 16,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: lightGrey.shade(50), width: 1),
            ),
            child: pw.Text(
              _buildExecutiveSummary(),
              style: pw.TextStyle(
                color: textColor,
                fontSize: 11,
              ),
            ),
          ),
        ],
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
            child: isSmallScreen 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTimeRangeDropdown()),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Refresh data',
                            onPressed: _loadAnalyticsData,
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Generate Report'),
                          onPressed: _generatePdfReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C49A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
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
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh data',
                        onPressed: _loadAnalyticsData,
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Generate Report'),
                        onPressed: _generatePdfReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
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
              _subscribeToAnalyticsData();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community Growth Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Tooltip(
                  message:
                      'Shows community growth over the selected time period',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
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

                          String periodLabel;
                          if (_selectedTimeRange == 'Last 7 Days') {
                            // For 7 days, show day labels
                            final dayNum = (value.toInt() + 1);
                            final date = DateTime.now()
                                .subtract(Duration(days: 7 - dayNum));
                            periodLabel = '${date.day}/${date.month}';
                          } else if (_selectedTimeRange == 'Last Year') {
                            // For a year, show month labels
                            final monthsAgo = 12 - (value.toInt() + 1);
                            final date = DateTime.now()
                                .subtract(Duration(days: monthsAgo * 30));
                            periodLabel =
                                '${date.month}/${date.year.toString().substring(2)}';
                          } else {
                            // For other periods, use standard M1, M3, etc.
                            String periodLetter =
                                _selectedTimeRange == 'Last 7 Days' ? 'D' : 'M';
                            periodLabel = '$periodLetter${value.toInt() + 1}';
                          }

                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              periodLabel,
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
                        interval: 20,
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
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: const Color(0xFF2D3748).withOpacity(0.8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            'Communities: ${touchedSpot.y.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              if (_analyticsData['totalUsers'] != null)
                                TextSpan(
                                  text:
                                      '\nUsers: ${_analyticsData['totalUsers']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    touchCallback: (_, __) {},
                    handleBuiltInTouches: true,
                  ),
                  minX: 0,
                  maxX: 9,
                  minY: 0,
                  // Make the chart y-axis dynamic but with minimum height to avoid flat lines in the middle
                  maxY: _getMaxY() > 0 ? _getMaxY() : 10,
                  lineBarsData: [
                    _createLineChartBarData(
                      _analyticsData['communityTrend'],
                      const Color(0xFF00C49A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Community Growth', const Color(0xFF00C49A)),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _getExplanatoryText(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the appropriate Y-axis maximum
  double _getMaxY() {
    final data = _analyticsData['communityTrend'] as List<dynamic>?;
    if (data != null && data.isNotEmpty) {
      // Convert all values to double before finding max value
      double maxValue = 0;
      double minValue = double.infinity;
      for (var value in data) {
        final doubleValue = value is num ? value.toDouble() : 0.0;
        if (doubleValue > maxValue) {
          maxValue = doubleValue;
        }
        if (doubleValue < minValue) {
          minValue = doubleValue;
        }
      }

      bool isFlat = maxValue == minValue;

      if (isFlat) {
        // For flat data, create a small range with the value at the bottom
        // This makes flat lines appear at the bottom instead of middle
        return maxValue + 5; // Just enough room to show the value at the bottom
      } else {
        // For non-flat data, round up to the nearest 10 and add some padding
        return (((maxValue / 10).ceil() + 1) * 10).toDouble();
      }
    }
    return 10.0; // Default if no data - small range to position line at bottom
  }

  // Helper method to get explanatory text
  String _getExplanatoryText() {
    final growth = _analyticsData['communityGrowth'] ?? 0.0;
    final direction = growth >= 0 ? 'increase' : 'decrease';
    final totalUsers = _analyticsData['totalUsers'] ??
        (_analyticsData['totalCommunities'] ?? 0) * 15; // Fallback estimate

    String period;
    switch (_selectedTimeRange) {
      case 'Last 7 Days':
        period = 'week';
        break;
      case 'Last 30 Days':
        period = 'month';
        break;
      case 'Last 90 Days':
        period = 'quarter';
        break;
      case 'Last Year':
        period = 'year';
        break;
      default:
        period = 'period';
    }

    final text =
        'Community Growth: ${growth.abs().toStringAsFixed(1)}% $direction this $period. '
        'Total active communities: ${_analyticsData['totalCommunities'] ?? 0}. '
        'Total active users: $totalUsers.';

    return text;
  }

  LineChartBarData _createLineChartBarData(List<dynamic>? data, Color color) {
    if (data == null || data.isEmpty) {
      return LineChartBarData(
        spots: List.generate(
          10,
          (index) => FlSpot(index.toDouble(), 0),
        ),
        isCurved: true,
        color: color,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: color,
              );
            }),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.4),
              color.withOpacity(0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }

    return LineChartBarData(
      spots: List.generate(
        data.length,
        (index) => FlSpot(index.toDouble(), data[index].toDouble()),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: color,
            );
          }),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.4),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
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

    return nonZeroRegions.map((entry) {
      final regionName = entry.key;
      final value = entry.value as int;
      final percentage = (value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: regionColors[regionName] ?? Colors.grey,
        value: value.toDouble(),
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

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16.0,
      runSpacing: 8.0,
      children: nonZeroRegions.map((entry) {
        final regionName = entry.key;
        final value = entry.value as int;
        final percentage = totalCommunities > 0
            ? (value / totalCommunities * 100).toStringAsFixed(1)
            : '0.0';

        return _buildPieLegendItem(regionName,
            regionColors[regionName] ?? Colors.grey, value, percentage);
      }).toList(),
    );
  }

  Widget _buildPieLegendItem(
      String label, Color color, int value, String percentage) {
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
