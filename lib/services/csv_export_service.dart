import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../models/firestore_user.dart';

class CsvExportService {
  // Generate CSV string from resident data
  Future<String> generateResidentCsv(List<FirestoreUser> users) async {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
        'Full Name,Email,Mobile,Birth Date,Age,Address,Barangay,Municipality,Verification Status,Joined Date');

    // CSV Rows
    for (var user in users) {
      final fullName = _escapeCsvField(user.fullName);
      final email = _escapeCsvField(user.email);
      final mobile = _escapeCsvField(user.mobile);
      final birthDate = DateFormat('MM/dd/yyyy').format(user.birthDate);
      final age = user.age.toString();
      final address = _escapeCsvField(user.address);
      final barangay = _escapeCsvField(user.location['barangay'] ?? '');
      final municipality = _escapeCsvField(user.location['municipality'] ?? '');
      final verificationStatus = _escapeCsvField(user.verificationStatus);
      final joinedDate = DateFormat('MM/dd/yyyy').format(user.createdAt);

      buffer.writeln(
          '$fullName,$email,$mobile,$birthDate,$age,$address,$barangay,$municipality,$verificationStatus,$joinedDate');
    }

    return buffer.toString();
  }

  // Generate CSV for a specific age group
  Future<String> generateAgeGroupCsv(
      List<FirestoreUser> users, String ageGroup) async {
    final filteredUsers =
        users.where((user) => user.ageGroup == ageGroup).toList();
    return generateResidentCsv(filteredUsers);
  }

  // Generate CSV for household report
  Future<String> generateHouseholdCsv(
      Map<String, List<FirestoreUser>> households) async {
    final buffer = StringBuffer();

    // CSV Header
    buffer
        .writeln('Address,Household Size,Members,Average Age,Contact Numbers');

    // CSV Rows
    households.forEach((address, members) {
      final householdSize = members.length.toString();
      final memberNames =
          _escapeCsvField(members.map((m) => m.fullName).join('; '));
      final averageAge = members.isEmpty
          ? '0'
          : (members.fold<int>(0, (sum, m) => sum + m.age) / members.length)
              .toStringAsFixed(1);
      final contacts = _escapeCsvField(members.map((m) => m.mobile).join('; '));

      buffer.writeln(
          '"$address",$householdSize,$memberNames,$averageAge,$contacts');
    });

    return buffer.toString();
  }

  // Save CSV to file and return file path
  Future<String> saveCsvToFile(String csvData, String filename) async {
    try {
      // Get the temporary directory (works on all platforms)
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';

      // Write the file
      final file = File(filePath);
      await file.writeAsString(csvData);

      return filePath;
    } catch (e) {
      debugPrint('Error saving CSV file: $e');
      rethrow;
    }
  }

  // Save and share CSV file using share dialog
  Future<String> saveAndShareCsv(String csvData, String filename) async {
    try {
      // Convert CSV string to bytes
      final bytes = Uint8List.fromList(csvData.codeUnits);

      // Use the printing package to save the file (same as PDF)
      // This opens the native save dialog instead of share sheet
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );

      return filename;
    } catch (e) {
      debugPrint('Error in saveAndShareCsv: $e');
      rethrow;
    }
  }

  // Escape CSV field to handle commas, quotes, and newlines
  String _escapeCsvField(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      // Escape quotes by doubling them
      final escapedField = field.replaceAll('"', '""');
      return '"$escapedField"';
    }
    return field;
  }

  // Generate CSV with custom columns
  Future<String> generateCustomCsv(
    List<FirestoreUser> users,
    List<String> columns,
  ) async {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(columns.join(','));

    // CSV Rows
    for (var user in users) {
      final row = <String>[];

      for (var column in columns) {
        switch (column.toLowerCase()) {
          case 'full name':
            row.add(_escapeCsvField(user.fullName));
            break;
          case 'email':
            row.add(_escapeCsvField(user.email));
            break;
          case 'mobile':
            row.add(_escapeCsvField(user.mobile));
            break;
          case 'birth date':
            row.add(DateFormat('MM/dd/yyyy').format(user.birthDate));
            break;
          case 'age':
            row.add(user.age.toString());
            break;
          case 'address':
            row.add(_escapeCsvField(user.address));
            break;
          case 'barangay':
            row.add(_escapeCsvField(user.location['barangay'] ?? ''));
            break;
          case 'municipality':
            row.add(_escapeCsvField(user.location['municipality'] ?? ''));
            break;
          case 'verification status':
            row.add(_escapeCsvField(user.verificationStatus));
            break;
          case 'joined date':
            row.add(DateFormat('MM/dd/yyyy').format(user.createdAt));
            break;
          default:
            row.add('');
        }
      }

      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  // Get default filename with timestamp
  String getDefaultFilename(String prefix) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefix}_$timestamp.csv';
  }
}
