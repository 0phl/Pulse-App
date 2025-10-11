import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/firestore_user.dart';

class ResidentPdfService {
  // Generate comprehensive resident directory PDF
  Future<void> generateResidentDirectoryPdf(
    List<FirestoreUser> users,
    Map<String, dynamic> demographics,
    String communityName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(communityName),
            pw.SizedBox(height: 20),
            _buildDemographicsSummary(demographics),
            pw.SizedBox(height: 20),
            _buildResidentTable(users),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Resident_Directory_${_getTimestamp()}.pdf',
    );
  }

  // Generate age group specific PDF
  Future<void> generateAgeGroupPdf(
    List<FirestoreUser> users,
    String ageGroup,
    String communityName,
  ) async {
    final filteredUsers =
        users.where((user) => user.ageGroup == ageGroup).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(communityName),
            pw.SizedBox(height: 10),
            pw.Text(
              'Age Group: $ageGroup',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            _buildResidentTable(filteredUsers),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${ageGroup}_Residents_${_getTimestamp()}.pdf',
    );
  }

  // Generate household report PDF
  Future<void> generateHouseholdReportPdf(
    Map<String, List<FirestoreUser>> households,
    String communityName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildPdfHeader(communityName),
            pw.SizedBox(height: 10),
            pw.Text(
              'Household Directory Report',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            _buildHouseholdTable(households),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Household_Report_${_getTimestamp()}.pdf',
    );
  }

  // Build PDF header
  pw.Widget _buildPdfHeader(String communityName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          communityName,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#00C49A'),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Resident Directory Report',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  // Build demographics summary
  pw.Widget _buildDemographicsSummary(Map<String, dynamic> demographics) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0F9F6'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Demographics Summary',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Residents',
                  demographics['totalResidents']?.toString() ?? '0'),
              _buildStatItem('Children (0-11)',
                  demographics['children']?.toString() ?? '0'),
              _buildStatItem(
                  'Youth (12-17)', demographics['youth']?.toString() ?? '0'),
              _buildStatItem(
                  'Adults (18-59)', demographics['adults']?.toString() ?? '0'),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                  'Seniors (60+)', demographics['seniors']?.toString() ?? '0'),
              _buildStatItem('Average Age',
                  '${demographics['averageAge']?.toString() ?? '0'} yrs'),
              _buildStatItem('Recent Registrations',
                  demographics['recentRegistrations']?.toString() ?? '0'),
              _buildStatItem('Verified',
                  '${demographics['verificationProgress']?.toString() ?? '0'}%'),
            ],
          ),
        ],
      ),
    );
  }

  // Build stat item for demographics
  pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Build resident table
  pw.Widget _buildResidentTable(List<FirestoreUser> users) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Resident List (${users.length} residents)',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#00C49A'),
              ),
              children: [
                _buildTableHeader('Name'),
                _buildTableHeader('Age'),
                _buildTableHeader('Address'),
                _buildTableHeader('Contact'),
                _buildTableHeader('Status'),
              ],
            ),
            // Data rows
            ...users.map((user) => pw.TableRow(
                  children: [
                    _buildTableCell(user.fullName),
                    _buildTableCell(user.age.toString()),
                    _buildTableCell(user.fullAddress),
                    _buildTableCell(user.mobile),
                    _buildTableCell(user.verificationStatus),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  // Build household table
  pw.Widget _buildHouseholdTable(Map<String, List<FirestoreUser>> households) {
    final householdList = households.entries.toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Household List (${householdList.length} households)',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#00C49A'),
              ),
              children: [
                _buildTableHeader('Address'),
                _buildTableHeader('Members'),
                _buildTableHeader('Member Names'),
                _buildTableHeader('Avg Age'),
              ],
            ),
            // Data rows
            ...householdList.map((entry) {
              final address = entry.key;
              final members = entry.value;
              final avgAge = members.isEmpty
                  ? '0'
                  : (members.fold<int>(0, (sum, m) => sum + m.age) /
                          members.length)
                      .toStringAsFixed(1);
              final names = members.map((m) => m.fullName).join(', ');

              return pw.TableRow(
                children: [
                  _buildTableCell(address),
                  _buildTableCell(members.length.toString()),
                  _buildTableCell(names),
                  _buildTableCell(avgAge),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // Build table header cell
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  // Build table data cell
  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  // Get timestamp for filename
  String _getTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }
}
