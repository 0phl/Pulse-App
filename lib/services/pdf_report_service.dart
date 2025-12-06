import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/report.dart';

class PdfReportService {
  // Date formatter
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');
  final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');

  /// Generate a comprehensive PDF report for complaint reports
  Future<void> generateComplaintReportsPdf({
    required List<Report> reports,
    required Map<String, dynamic> reportStats,
    required String barangayName,
    required String adminName,
    String? barangayAddress,
    DateTime? startDate,
    DateTime? endDate,
    bool includeDetailedList = false,
    String? filterStatus,
  }) async {
    final pdf = pw.Document();

    // Prepare data
    final statusCounts = reportStats['statusCounts'] as Map<String, dynamic>? ?? {};
    final typeDistribution = reportStats['typeDistribution'] as Map<String, dynamic>? ?? {};
    final weeklyData = reportStats['weeklyData'] as List<dynamic>? ?? [];
    final avgResolutionTime = reportStats['avgResolutionTime'] as String? ?? '0.0';

    // Calculate metrics
    final totalReports = statusCounts['total'] ?? 0;
    final resolvedCount = statusCounts['resolved'] ?? 0;
    final pendingCount = statusCounts['pending'] ?? 0;
    final inProgressCount = statusCounts['in_progress'] ?? 0;
    final rejectedCount = statusCounts['rejected'] ?? 0;
    
    final resolutionRate = totalReports > 0 
        ? ((resolvedCount / totalReports) * 100).toStringAsFixed(1)
        : '0.0';

    // Generate period text
    String reportPeriod;
    if (startDate != null && endDate != null) {
      reportPeriod = '${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}';
    } else if (startDate != null) {
      reportPeriod = 'From ${_dateFormat.format(startDate)}';
    } else if (endDate != null) {
      reportPeriod = 'Until ${_dateFormat.format(endDate)}';
    } else {
      reportPeriod = 'All Time';
    }

    final generatedDate = _dateTimeFormat.format(DateTime.now());
    final documentReference = 'BR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Add pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          _buildHeader(barangayName, barangayAddress, reportPeriod, generatedDate, adminName),
          pw.SizedBox(height: 20),

          // Executive Summary
          _buildExecutiveSummary(
            totalReports,
            resolvedCount,
            pendingCount,
            inProgressCount,
            rejectedCount,
            resolutionRate,
            avgResolutionTime,
          ),
          pw.SizedBox(height: 20),

          // Issue Type Distribution Table
          _buildIssueTypeTable(typeDistribution, totalReports),
          pw.SizedBox(height: 20),

          // Weekly Trend Chart
          _buildWeeklyTrendSection(weeklyData),
          pw.SizedBox(height: 20),

          // Top Problem Areas
          _buildTopProblemAreas(reports),
          pw.SizedBox(height: 20),

          // Detailed List (if enabled)
          if (includeDetailedList) ...[
            pw.SizedBox(height: 10),
            _buildDetailedReportsList(reports),
          ],
        ],
        footer: (context) => _buildFooter(
          context.pageNumber,
          context.pagesCount,
          documentReference,
          adminName,
          barangayName,
        ),
      ),
    );

    // Use Printing.layoutPdf for consistent cross-platform behavior
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Complaint_Report_${barangayName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Build header section
  pw.Widget _buildHeader(
    String barangayName,
    String? barangayAddress,
    String reportPeriod,
    String generatedDate,
    String adminName,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Title
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#00C49A'), width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                barangayName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#00C49A'),
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'COMPLAINT REPORTS SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#00C49A'),
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Report Period: $reportPeriod',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated: $generatedDate',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Build executive summary section
  pw.Widget _buildExecutiveSummary(
    int totalReports,
    int resolvedCount,
    int pendingCount,
    int inProgressCount,
    int rejectedCount,
    String resolutionRate,
    String avgResolutionTime,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EXECUTIVE SUMMARY',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#00C49A'),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              // Top row metrics
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCard('Total Complaints', totalReports.toString(), PdfColor.fromHex('#00C49A')),
                  _buildMetricCard('Resolved', resolvedCount.toString(), PdfColors.green700),
                  _buildMetricCard('Pending', pendingCount.toString(), PdfColors.orange700),
                  _buildMetricCard('In Progress', inProgressCount.toString(), PdfColor.fromHex('#00C49A')),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              // Bottom row metrics
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCard('Resolution Rate', '$resolutionRate%', PdfColor.fromHex('#00C49A')),
                  _buildMetricCard('Avg. Resolution Time', '$avgResolutionTime days', PdfColor.fromHex('#00C49A')),
                  _buildMetricCard('Rejected', rejectedCount.toString(), PdfColors.red700),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build metric card
  pw.Widget _buildMetricCard(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Build issue type distribution table
  pw.Widget _buildIssueTypeTable(Map<String, dynamic> typeDistribution, int totalReports) {
    // Sort by count descending
    final sortedTypes = typeDistribution.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'COMPLAINTS BY ISSUE TYPE',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#00C49A'),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00C49A')),
              children: [
                _buildTableCell('Issue Type', isHeader: true),
                _buildTableCell('Count', isHeader: true),
                _buildTableCell('% of Total', isHeader: true),
              ],
            ),
            // Data rows
            ...sortedTypes.map((entry) {
              final count = entry.value as int;
              final percentage = totalReports > 0 
                  ? ((count / totalReports) * 100).toStringAsFixed(1)
                  : '0.0';
              return pw.TableRow(
                children: [
                  _buildTableCell(entry.key),
                  _buildTableCell(count.toString()),
                  _buildTableCell('$percentage%'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Build table cell
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  /// Build weekly trend section
  pw.Widget _buildWeeklyTrendSection(List<dynamic> weeklyData) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = weeklyData.isEmpty 
        ? 1 
        : weeklyData.reduce((a, b) => (a as int) > (b as int) ? a : b) as int;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'WEEKLY REPORTS TREND (Last 7 Days)',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#00C49A'),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 120,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final value = index < weeklyData.length ? weeklyData[index] as int : 0;
              final height = maxValue > 0 ? (value / maxValue) * 80 : 0.0;
              
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  if (value > 0)
                    pw.Text(
                      value.toString(),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 30,
                    height: height,
                    color: PdfColor.fromHex('#00C49A'),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    days[index],
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Build top problem areas section
  pw.Widget _buildTopProblemAreas(List<Report> reports) {
    // Count complaints by location
    final locationCounts = <String, int>{};
    for (final report in reports) {
      final address = report.address.split('(').first.trim(); // Get main address before details
      locationCounts[address] = (locationCounts[address] ?? 0) + 1;
    }

    // Sort and get top 5
    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocations = sortedLocations.take(5).toList();

    if (topLocations.isEmpty) {
      return pw.SizedBox.shrink();
    }

    // Wrap in Column with keepTogether to prevent page break between title and table
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TOP 5 PROBLEM AREAS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#00C49A'),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#00C49A')),
                  children: [
                    _buildTableCell('Rank', isHeader: true),
                    _buildTableCell('Location', isHeader: true),
                    _buildTableCell('Complaints', isHeader: true),
                  ],
                ),
                ...topLocations.asMap().entries.map((entry) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell((entry.key + 1).toString()),
                      _buildTableCell(entry.value.key),
                      _buildTableCell(entry.value.value.toString()),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Build detailed reports list
  pw.Widget _buildDetailedReportsList(List<Report> reports) {
    if (reports.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            'DETAILED COMPLAINTS LIST',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#00C49A'),
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        ...reports.asMap().entries.map((entry) {
          final index = entry.key;
          final report = entry.value;
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Report #${(index + 1).toString().padLeft(3, '0')}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: _getStatusColor(report.status.value),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Text(
                            report.status.value.toUpperCase().replaceAll('_', ' '),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(height: 8, color: PdfColors.grey400),
                    _buildReportDetail('Issue Type:', report.issueType),
                    _buildReportDetail('Location:', report.address),
                    _buildReportDetail('Date Filed:', _dateTimeFormat.format(report.createdAt)),
                    if (report.description.isNotEmpty)
                      _buildReportDetail('Description:', report.description),
                    if (report.resolutionDetails != null && report.resolutionDetails!.isNotEmpty)
                      _buildReportDetail('Resolution:', report.resolutionDetails!),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  /// Build report detail row
  pw.Widget _buildReportDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// Get status color
  PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return PdfColors.orange;
      case 'in_progress':
        return PdfColors.purple;
      case 'resolved':
        return PdfColors.green;
      case 'rejected':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  /// Build footer
  pw.Widget _buildFooter(
    int pageNumber,
    int totalPages,
    String documentReference,
    String adminName,
    String barangayName,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document Reference: $documentReference',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page $pageNumber of $totalPages',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'This is an official document of $barangayName',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }
}