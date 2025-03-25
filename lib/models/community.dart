import 'package:cloud_firestore/cloud_firestore.dart';
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
    if (data != null) {
      // Handle case where id and data are passed separately
      return Community(
        id: source as String,
        name: data['name'] as String,
        adminId: data['adminId'] as String? ?? '',
        adminName: data['adminName'] as String? ?? '',
        adminAvatar: data['adminAvatar'] as String?,
        description: data['description'] as String?,
        coverImage: data['coverImage'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int? ?? 0),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(data['updatedAt'] as int? ?? 0),
        membersCount: data['membersCount'] as int? ?? 0,
        notices: data['notices'] != null
            ? (data['notices'] as List)
                .map((notice) =>
                    CommunityNotice.fromMap(notice as Map<String, dynamic>))
                .toList()
            : [],
      );
    }

    // Handle case where everything is in a single map
    final map = source as Map<String, dynamic>;
    return Community(
      id: map['id'] as String,
      name: map['name'] as String,
      adminId: map['adminId'] as String,
      adminName: map['adminName'] as String,
      adminAvatar: map['adminAvatar'] as String?,
      description: map['description'] as String?,
      coverImage: map['coverImage'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      membersCount: map['membersCount'] as int? ?? 0,
      notices: map['notices'] != null
          ? (map['notices'] as List)
              .map((notice) =>
                  CommunityNotice.fromMap(notice as Map<String, dynamic>))
              .toList()
          : [],
    );
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
}
