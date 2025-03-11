import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUser {
  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String mobile;
  final DateTime birthDate;
  final String address;
  final Map<String, String> location;
  final String communityId;
  final String role;
  final DateTime createdAt;

  FirestoreUser({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    required this.mobile,
    required this.birthDate,
    required this.address,
    required this.location,
    required this.communityId,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'username': username,
      'email': email,
      'mobile': mobile,
      'birthDate': Timestamp.fromDate(birthDate),
      'address': address,
      'location': location,
      'communityId': communityId,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FirestoreUser.fromMap(Map<String, dynamic> map) {
    return FirestoreUser(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      address: map['address'] ?? '',
      location: Map<String, String>.from(map['location'] ?? {}),
      communityId: map['communityId'] ?? '',
      role: map['role'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
