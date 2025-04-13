import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUser {
  final String uid;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String username;
  final String email;
  final String mobile;
  final DateTime birthDate;
  final String address;
  final Map<String, String> location;
  final String communityId;
  final String role;
  final DateTime createdAt;
  final String? profileImageUrl;

  // Get full name by combining first, middle, and last names
  String get fullName {
    if (middleName != null && middleName!.isNotEmpty) {
      return '$firstName $middleName $lastName';
    }
    return '$firstName $lastName';
  }

  FirestoreUser({
    required this.uid,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.mobile,
    required this.birthDate,
    required this.address,
    required this.location,
    required this.communityId,
    required this.role,
    required this.createdAt,
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      if (middleName != null && middleName!.isNotEmpty) 'middleName': middleName,
      'lastName': lastName,
      'fullName': fullName, // Store the combined name for backward compatibility
      'username': username,
      'email': email,
      'mobile': mobile,
      'birthDate': Timestamp.fromDate(birthDate),
      'address': address,
      'location': location,
      'communityId': communityId,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    };
  }

  factory FirestoreUser.fromMap(Map<String, dynamic> map) {
    // Handle both new format (firstName, lastName) and old format (fullName)
    String firstName = map['firstName'] ?? '';
    String? middleName = map['middleName'];
    String lastName = map['lastName'] ?? '';

    // If we don't have firstName/lastName but have fullName, parse it
    if ((firstName.isEmpty || lastName.isEmpty) && map['fullName'] != null) {
      final nameParts = (map['fullName'] as String).split(' ');
      if (nameParts.length >= 2) {
        firstName = nameParts.first;
        lastName = nameParts.last;
        if (nameParts.length > 2) {
          // Join any middle parts as the middle name
          middleName = nameParts.sublist(1, nameParts.length - 1).join(' ');
        }
      } else if (nameParts.length == 1) {
        firstName = nameParts.first;
        lastName = '';
      }
    }

    return FirestoreUser(
      uid: map['uid'] ?? '',
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      address: map['address'] ?? '',
      location: Map<String, String>.from(map['location'] ?? {}),
      communityId: map['communityId'] ?? '',
      role: map['role'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      profileImageUrl: map['profileImageUrl'],
    );
  }
}
