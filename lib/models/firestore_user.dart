import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final String registrationId;
  final String verificationStatus;

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
    required this.registrationId,
    required this.verificationStatus,
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
      'registrationId': registrationId,
      'verificationStatus': verificationStatus,
    };
  }

  // Helper method to parse birth date from various formats
  static DateTime _parseBirthDate(dynamic birthDateValue) {
    return parseDateTime(birthDateValue);
  }

  // Helper method to parse created at date from various formats
  static DateTime _parseCreatedAt(dynamic createdAtValue) {
    return parseDateTime(createdAtValue);
  }

  // Generic date time parser - public so it can be used by other classes
  static DateTime parseDateTime(dynamic dateTimeValue) {
    try {
      if (dateTimeValue is Timestamp) {
        return dateTimeValue.toDate();
      } else if (dateTimeValue is DateTime) {
        return dateTimeValue;
      } else if (dateTimeValue is String) {
        // Try to parse MM/DD/YYYY format
        final parts = dateTimeValue.split('/');
        if (parts.length == 3) {
          final month = int.tryParse(parts[0]) ?? 1;
          final day = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? 2000;
          return DateTime(year, month, day);
        }
        // Try other date formats if needed
        return DateTime.tryParse(dateTimeValue) ?? DateTime.now();
      } else if (dateTimeValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateTimeValue);
      }
    } catch (e) {
      debugPrint('Error parsing date time: $e');
    }
    // Default to current date if parsing fails
    return DateTime.now();
  }

  factory FirestoreUser.fromMap(Map<String, dynamic> map) {
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
      birthDate: _parseBirthDate(map['birthDate']),
      address: map['address'] ?? '',
      location: Map<String, String>.from(map['location'] ?? {}),
      communityId: map['communityId'] ?? '',
      role: map['role'] ?? '',
      createdAt: _parseCreatedAt(map['createdAt']),
      profileImageUrl: map['profileImageUrl'],
      registrationId: map['registrationId'] ?? '',
      verificationStatus: map['verificationStatus'] ?? 'pending',
    );
  }
}
