import 'package:cloud_firestore/cloud_firestore.dart';

class BarangayProfile {
  final String id;
  final String name;
  final String adminId;
  final String adminName;
  final String? adminEmail;
  final String? adminPhone;
  final String? adminAvatar;
  final String region;
  final String province;
  final String municipality;
  final String barangayCode;
  final String address;
  final DateTime registeredAt;
  final String status; // active, inactive, pending
  final BarangayAnalytics analytics;

  BarangayProfile({
    required this.id,
    required this.name,
    required this.adminId,
    required this.adminName,
    this.adminEmail,
    this.adminPhone,
    this.adminAvatar,
    required this.region,
    required this.province,
    required this.municipality,
    required this.barangayCode,
    required this.address,
    required this.registeredAt,
    required this.status,
    required this.analytics,
  });

  factory BarangayProfile.fromMap(String id, Map<dynamic, dynamic> data) {
    return BarangayProfile(
      id: id,
      name: data['name']?.toString() ?? 'Unknown Barangay',
      adminId: data['adminId']?.toString() ?? '',
      adminName: data['adminName']?.toString() ?? '',
      adminEmail: data['adminEmail']?.toString(),
      adminPhone: data['adminPhone']?.toString(),
      adminAvatar: data['adminAvatar']?.toString(),
      region: data['region']?.toString() ?? '',
      province: data['province']?.toString() ?? '',
      municipality: data['municipality']?.toString() ?? '',
      barangayCode: data['barangayCode']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      registeredAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              data['createdAt'] is int ? data['createdAt'] : 0),
      status: data['status']?.toString() ?? 'pending',
      analytics: BarangayAnalytics.fromMap(data['analytics'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'adminId': adminId,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'adminPhone': adminPhone,
      'adminAvatar': adminAvatar,
      'region': region,
      'province': province,
      'municipality': municipality,
      'barangayCode': barangayCode,
      'address': address,
      'registeredAt': registeredAt,
      'status': status,
      'analytics': analytics.toMap(),
    };
  }

  String get fullAddress {
    return '$address, $name, $municipality, $province';
  }
}

class BarangayAnalytics {
  final int totalRegisteredUsers;
  final int totalActiveUsers;
  final int publicPostsCount;
  final int reportsSubmitted;
  final int volunteerParticipants;
  final Map<String, int> monthlyUserGrowth;
  final Map<String, int> weeklyVolunteers;
  final Map<String, int> categoryReports;
  final DateTime lastUpdated;

  BarangayAnalytics({
    required this.totalRegisteredUsers,
    required this.totalActiveUsers,
    required this.publicPostsCount,
    required this.reportsSubmitted,
    required this.volunteerParticipants,
    required this.monthlyUserGrowth,
    required this.weeklyVolunteers,
    required this.categoryReports,
    required this.lastUpdated,
  });

  factory BarangayAnalytics.fromMap(Map<dynamic, dynamic> data) {
    return BarangayAnalytics(
      totalRegisteredUsers: data['totalRegisteredUsers'] is int
          ? data['totalRegisteredUsers']
          : 0,
      totalActiveUsers:
          data['totalActiveUsers'] is int ? data['totalActiveUsers'] : 0,
      publicPostsCount:
          data['publicPostsCount'] is int ? data['publicPostsCount'] : 0,
      reportsSubmitted:
          data['reportsSubmitted'] is int ? data['reportsSubmitted'] : 0,
      volunteerParticipants: data['volunteerParticipants'] is int
          ? data['volunteerParticipants']
          : 0,
      monthlyUserGrowth: Map<String, int>.from(data['monthlyUserGrowth'] ?? {}),
      weeklyVolunteers: Map<String, int>.from(data['weeklyVolunteers'] ?? {}),
      categoryReports: Map<String, int>.from(data['categoryReports'] ?? {}),
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(data['lastUpdated'] is int
              ? data['lastUpdated']
              : DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalRegisteredUsers': totalRegisteredUsers,
      'totalActiveUsers': totalActiveUsers,
      'publicPostsCount': publicPostsCount,
      'reportsSubmitted': reportsSubmitted,
      'volunteerParticipants': volunteerParticipants,
      'monthlyUserGrowth': monthlyUserGrowth,
      'weeklyVolunteers': weeklyVolunteers,
      'categoryReports': categoryReports,
      'lastUpdated': lastUpdated,
    };
  }

  double get activeUserPercentage {
    if (totalRegisteredUsers == 0) return 0.0;
    return (totalActiveUsers / totalRegisteredUsers) * 100;
  }

  int get thisWeekVolunteers {
    final now = DateTime.now();
    final weekKey = '${now.year}-W${_getWeekOfYear(now)}';
    return weeklyVolunteers[weekKey] ?? 0;
  }

  int get thisMonthUserGrowth {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return monthlyUserGrowth[monthKey] ?? 0;
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}
