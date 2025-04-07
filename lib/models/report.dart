import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_status.dart';

class Report {
  final String id;
  final String userId;
  final String communityId;
  final String issueType;
  final String description;
  final String address;
  final Map<String, dynamic> location; // Contains lat, lng, street, locality, subAdministrativeArea
  final List<String> photoUrls;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolutionDetails; // Added field for resolution details

  Report({
    required this.id,
    required this.userId,
    required this.communityId,
    required this.issueType,
    required this.description,
    required this.address,
    required this.location,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionDetails,
  });

  // Create from Firestore document
  factory Report.fromMap(Map<String, dynamic> map, String documentId) {
    // Handle potential null timestamps by providing default values
    final createdAt = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final updatedAt = map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : DateTime.now();

    return Report(
      id: documentId,
      userId: map['userId'] as String,
      communityId: map['communityId'] as String,
      issueType: map['issueType'] as String,
      description: map['description'] as String,
      address: map['address'] as String,
      location: map['location'] as Map<String, dynamic>,
      photoUrls: List<String>.from(map['photoUrls']),
      status: ReportStatus.fromString(map['status'] as String),
      createdAt: createdAt,
      updatedAt: updatedAt,
      resolutionDetails: map['resolutionDetails'] as String?,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    final map = {
      'id': id, // Include the ID in the map
      'userId': userId,
      'communityId': communityId,
      'issueType': issueType,
      'description': description,
      'address': address,
      'location': location,
      'photoUrls': photoUrls,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    // Add resolution details if available
    if (resolutionDetails != null) {
      map['resolutionDetails'] = resolutionDetails!;
    }

    return map;
  }

  // Create a copy of the report with modified fields
  Report copyWith({
    String? id,
    String? userId,
    String? communityId,
    String? issueType,
    String? description,
    String? address,
    Map<String, dynamic>? location,
    List<String>? photoUrls,
    ReportStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? resolutionDetails,
  }) {
    return Report(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      communityId: communityId ?? this.communityId,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      address: address ?? this.address,
      location: location ?? this.location,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolutionDetails: resolutionDetails ?? this.resolutionDetails,
    );
  }
}
