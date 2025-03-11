import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  final String uid;
  final String fullName;
  final String email;
  final String communityId;
  final bool isFirstLogin;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  AdminUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.communityId,
    required this.isFirstLogin,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'communityId': communityId,
      'role': 'admin', // Always set role as admin for this model
      'isFirstLogin': isFirstLogin,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  static AdminUser fromMap(Map<String, dynamic> map) {
    final createdAtTimestamp = map['createdAt'] as Timestamp?;
    final updatedAtTimestamp = map['updatedAt'] as Timestamp?;
    final lastLoginAtTimestamp = map['lastLoginAt'] as Timestamp?;

    return AdminUser(
      uid: map['uid'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      communityId: map['communityId'] as String,
      isFirstLogin: map['isFirstLogin'] as bool,
      status: map['status'] as String,
      createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
      updatedAt: updatedAtTimestamp?.toDate(),
      lastLoginAt: lastLoginAtTimestamp?.toDate(),
    );
  }

  AdminUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? communityId,
    bool? isFirstLogin,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AdminUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      communityId: communityId ?? this.communityId,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
