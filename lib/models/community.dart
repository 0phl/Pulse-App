import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'community_notice.dart';

class Community {
  final String id;
  final String name;
  final String adminId;
  final String adminName;
  final String? adminAvatar;
  final String? description;
  final String? coverImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int membersCount;
  final List<CommunityNotice> notices;

  Community({
    required this.id,
    required this.name,
    required this.adminId,
    required this.adminName,
    this.adminAvatar,
    this.description,
    this.coverImage,
    required this.createdAt,
    required this.updatedAt,
    required this.membersCount,
    this.notices = const [],
  });

  factory Community.fromMap(dynamic source, [Map<dynamic, dynamic>? data]) {
    try {
      if (data != null) {
        // Handle case where id and data are passed separately
        String id = source.toString();
        String name = data['name']?.toString() ?? 'Unknown Community';
        String adminId = data['adminId']?.toString() ?? '';
        String adminName = data['adminName']?.toString() ?? '';

        return Community(
          id: id,
          name: name,
          adminId: adminId,
          adminName: adminName,
          adminAvatar: data['adminAvatar']?.toString(),
          description: data['description']?.toString(),
          coverImage: data['coverImage']?.toString(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              data['createdAt'] is int ? data['createdAt'] : 0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
              data['updatedAt'] is int ? data['updatedAt'] : 0),
          membersCount: data['membersCount'] is int ? data['membersCount'] : 0,
          notices: data['notices'] is List
              ? (data['notices'] as List)
                  .whereType<Map>()
                  .map((notice) => CommunityNotice.fromMap(notice))
                  .toList()
              : [],
        );
      }

      // Handle case where everything is in a single map
      if (source is! Map) {
        throw FormatException('Source is not a Map: $source');
      }

      final map = source;

      return Community(
        id: map['id']?.toString() ?? 'unknown',
        name: map['name']?.toString() ?? 'Unknown Community',
        adminId: map['adminId']?.toString() ?? '',
        adminName: map['adminName']?.toString() ?? '',
        adminAvatar: map['adminAvatar']?.toString(),
        description: map['description']?.toString(),
        coverImage: map['coverImage']?.toString(),
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] is int ? map['createdAt'] : 0),
        updatedAt: map['updatedAt'] is Timestamp
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] is int ? map['updatedAt'] : 0),
        membersCount: map['membersCount'] is int ? map['membersCount'] : 0,
        notices: map['notices'] is List
            ? (map['notices'] as List)
                .whereType<Map>()
                .map((notice) => CommunityNotice.fromMap(notice))
                .toList()
            : [],
      );
    } catch (e) {
      debugPrint('Error in Community.fromMap: $e');
      // Return a fallback community to prevent app crashes
      return Community(
        id: 'error',
        name: 'Error Loading Community',
        adminId: '',
        adminName: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        membersCount: 0,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'adminId': adminId,
      'adminName': adminName,
      'adminAvatar': adminAvatar,
      'description': description,
      'coverImage': coverImage,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'membersCount': membersCount,
      'notices': notices.map((notice) => notice.toMap()).toList(),
    };
  }

  Community copyWith({
    String? id,
    String? name,
    String? adminId,
    String? adminName,
    String? adminAvatar,
    String? description,
    String? coverImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? membersCount,
    List<CommunityNotice>? notices,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      adminAvatar: adminAvatar ?? this.adminAvatar,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      membersCount: membersCount ?? this.membersCount,
      notices: notices ?? this.notices,
    );
  }

  static String createLocationId(
      String region, String province, String city, String barangay) {
    return '$region:$province:$city:$barangay'.toLowerCase();
  }

  static String createLocationStatusId(
      String region, String province, String city, String barangay, String status) {
    return '$region:$province:$city:$barangay:$status'.toLowerCase();
  }
}
