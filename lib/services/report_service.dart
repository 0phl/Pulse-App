import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';
import '../models/report_status.dart';
import 'cloudinary_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService;

  ReportService(this._cloudinaryService);

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  // Create a new report
  Future<Report> createReport({
    required String userId,
    required String communityId,
    required String issueType,
    required String description,
    required String address,
    required Map<String, dynamic> location,
    required List<String> photoUrls,
    List<String> videoUrls = const [],
    String? street,
    String? locality,
    String? subAdministrativeArea,
  }) async {
    final now = DateTime.now();

    final docRef = await _reports.add({
      'userId': userId,
      'communityId': communityId,
      'issueType': issueType,
      'description': description,
      'address': address,
      'location': location,
      'photoUrls': photoUrls,
      'videoUrls': videoUrls,
      'status': ReportStatus.pending.value,
      'street': street,
      'locality': locality,
      'subAdministrativeArea': subAdministrativeArea,
      'createdAt': now,
      'updatedAt': now,
    });

    return Report.fromMap(
      (await docRef.get()).data()!,
      docRef.id,
    );
  }

  // Get a single report by ID
  Future<Report?> getReport(String reportId) async {
    final doc = await _reports.doc(reportId).get();
    if (!doc.exists) return null;
    return Report.fromMap(doc.data()!, doc.id);
  }

  // Get reports for a community with optional filters
  Stream<List<Report>> getReports({
    required String communityId,
    ReportStatus? status,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _reports
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Report.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Update report status
  Future<void> updateReportStatus(String reportId, ReportStatus newStatus) async {
    await _reports.doc(reportId).update({
      'status': newStatus.value,
      'updatedAt': DateTime.now(),
    });
  }

  // Update report details
  Future<void> updateReport(String reportId, {
    String? description,
    String? address,
    Map<String, dynamic>? location,
    List<String>? photoUrls,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (description != null) updates['description'] = description;
    if (address != null) updates['address'] = address;
    if (location != null) updates['location'] = location;
    if (photoUrls != null) updates['photoUrls'] = photoUrls;

    await _reports.doc(reportId).update(updates);
  }

  // Upload photos for a report
  Future<List<String>> uploadReportPhotos(List<File> files) async {
    return await _cloudinaryService.uploadReportImages(files);
  }

  // Upload videos for a report
  Future<List<String>> uploadReportVideos(List<File> files) async {
    return await _cloudinaryService.uploadReportVideos(files);
  }

  // Delete a report
  Future<void> deleteReport(String reportId) async {
    // We're only deleting the report document since Cloudinary URLs are managed separately
    await _reports.doc(reportId).delete();
  }
}