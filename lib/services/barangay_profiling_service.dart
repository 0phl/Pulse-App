import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/barangay_profile.dart';
import '../models/community.dart';
import 'dart:async';

class BarangayProfilingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all barangay profiles with analytics
  Stream<List<BarangayProfile>> getBarangayProfilesStream() {
    return _database.ref().child('communities').onValue.asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <BarangayProfile>[];

      List<BarangayProfile> profiles = [];

      for (var entry in data.entries) {
        try {
          final communityData = entry.value as Map<dynamic, dynamic>;
          final communityId = entry.key as String;

          // Calculate analytics for this barangay
          final analytics =
              await _calculateBarangayAnalytics(communityId, communityData);

          // Create barangay profile
          final profile = BarangayProfile(
            id: communityId,
            name: communityData['name']?.toString() ?? 'Unknown Barangay',
            adminId: communityData['adminId']?.toString() ?? '',
            adminName: communityData['adminName']?.toString() ?? '',
            adminEmail:
                await _getAdminEmail(communityData['adminId']?.toString()),
            adminPhone:
                await _getAdminPhone(communityData['adminId']?.toString()),
            adminAvatar: communityData['adminAvatar']?.toString(),
            region: communityData['region']?.toString() ?? '',
            province: communityData['province']?.toString() ?? '',
            municipality: communityData['municipality']?.toString() ?? '',
            barangayCode: communityData['barangayCode']?.toString() ?? '',
            address: _buildFullAddress(communityData),
            registeredAt: communityData['createdAt'] is int
                ? DateTime.fromMillisecondsSinceEpoch(
                    communityData['createdAt'])
                : DateTime.now(),
            status: communityData['status']?.toString() ?? 'pending',
            analytics: analytics,
          );

          profiles.add(profile);
        } catch (e) {
          continue;
        }
      }

      return profiles;
    });
  }

  // Get single barangay profile
  Future<BarangayProfile?> getBarangayProfile(String communityId) async {
    try {
      final snapshot =
          await _database.ref().child('communities').child(communityId).get();
      if (!snapshot.exists) return null;

      final communityData = snapshot.value as Map<dynamic, dynamic>;
      final analytics =
          await _calculateBarangayAnalytics(communityId, communityData);

      return BarangayProfile(
        id: communityId,
        name: communityData['name']?.toString() ?? 'Unknown Barangay',
        adminId: communityData['adminId']?.toString() ?? '',
        adminName: communityData['adminName']?.toString() ?? '',
        adminEmail: await _getAdminEmail(communityData['adminId']?.toString()),
        adminPhone: await _getAdminPhone(communityData['adminId']?.toString()),
        adminAvatar: communityData['adminAvatar']?.toString(),
        region: communityData['region']?.toString() ?? '',
        province: communityData['province']?.toString() ?? '',
        municipality: communityData['municipality']?.toString() ?? '',
        barangayCode: communityData['barangayCode']?.toString() ?? '',
        address: _buildFullAddress(communityData),
        registeredAt: communityData['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(communityData['createdAt'])
            : DateTime.now(),
        status: communityData['status']?.toString() ?? 'pending',
        analytics: analytics,
      );
    } catch (e) {
      return null;
    }
  }

  // Calculate analytics for a specific barangay
  Future<BarangayAnalytics> _calculateBarangayAnalytics(
      String communityId, Map<dynamic, dynamic> communityData) async {
    try {
      // Get total registered users for this barangay
      final totalUsers = await _getTotalRegisteredUsers(
          communityData['barangayCode']?.toString());

      // Get active users (active in last 30 days)
      final activeUsers =
          await _getActiveUsers(communityData['barangayCode']?.toString());

      // Get public posts count
      final publicPosts = await _getPublicPostsCount(communityId);

      // Get reports submitted
      final reportsCount = await _getReportsCount(communityId);

      // Get volunteer participants
      final volunteerCount = await _getVolunteerParticipants(communityId);

      // Get monthly user growth
      final monthlyGrowth = await _getMonthlyUserGrowth(
          communityData['barangayCode']?.toString());

      // Get weekly volunteers
      final weeklyVolunteers = await _getWeeklyVolunteers(communityId);

      // Get category reports
      final categoryReports = await _getCategoryReports(communityId);

      return BarangayAnalytics(
        totalRegisteredUsers: totalUsers,
        totalActiveUsers: activeUsers,
        publicPostsCount: publicPosts,
        reportsSubmitted: reportsCount,
        volunteerParticipants: volunteerCount,
        monthlyUserGrowth: monthlyGrowth,
        weeklyVolunteers: weeklyVolunteers,
        categoryReports: categoryReports,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return BarangayAnalytics(
        totalRegisteredUsers: 0,
        totalActiveUsers: 0,
        publicPostsCount: 0,
        reportsSubmitted: 0,
        volunteerParticipants: 0,
        monthlyUserGrowth: {},
        weeklyVolunteers: {},
        categoryReports: {},
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Helper methods for analytics calculation
  Future<int> _getTotalRegisteredUsers(String? barangayCode) async {
    if (barangayCode == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('location.barangayCode', isEqualTo: barangayCode)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getActiveUsers(String? barangayCode) async {
    if (barangayCode == null) return 0;

    try {
      final activeThreshold = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('users')
          .where('location.barangayCode', isEqualTo: barangayCode)
          .where('role', isEqualTo: 'member')
          .where('lastActive',
              isGreaterThan: Timestamp.fromDate(activeThreshold))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      try {
        final allUsersSnapshot = await _firestore
            .collection('users')
            .where('location.barangayCode', isEqualTo: barangayCode)
            .get();

        final members = allUsersSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['role'] == 'member';
        }).toList();

        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        int activeCount = 0;

        for (var doc in members) {
          final data = doc.data();
          final lastActive = data['lastActive'] as Timestamp?;

          if (lastActive != null) {
            final lastActiveDate = lastActive.toDate();
            if (lastActiveDate.isAfter(thirtyDaysAgo)) {
              activeCount++;
            }
          }
        }

        return activeCount;
      } catch (fallbackError) {
        return 0;
      }
    }
  }

  Future<int> _getPublicPostsCount(String communityId) async {
    try {
      final snapshot = await _database
          .ref()
          .child('community_notices')
          .orderByChild('communityId')
          .equalTo(communityId)
          .get();

      if (!snapshot.exists) return 0;

      final data = snapshot.value as Map<dynamic, dynamic>?;
      return data?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getReportsCount(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('communityId', isEqualTo: communityId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getVolunteerParticipants(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('volunteer_posts')
          .where('communityId', isEqualTo: communityId)
          .get();

      int totalParticipants = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['joinedUsers'] is List) {
          totalParticipants += (data['joinedUsers'] as List).length;
        }
      }
      return totalParticipants;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, int>> _getMonthlyUserGrowth(String? barangayCode) async {
    if (barangayCode == null) return {};

    try {
      final Map<String, int> monthlyGrowth = {};
      final now = DateTime.now();

      for (int i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final monthKey =
            '${month.year}-${month.month.toString().padLeft(2, '0')}';

        final snapshot = await _firestore
            .collection('users')
            .where('location.barangayCode', isEqualTo: barangayCode)
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(month))
            .where('createdAt', isLessThan: Timestamp.fromDate(nextMonth))
            .get();

        monthlyGrowth[monthKey] = snapshot.docs.length;
      }

      return monthlyGrowth;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> _getWeeklyVolunteers(String communityId) async {
    try {
      final Map<String, int> weeklyVolunteers = {};
      final now = DateTime.now();

      for (int i = 0; i < 8; i++) {
        final weekStart =
            now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
        final weekEnd = weekStart.add(const Duration(days: 6));
        final weekKey = '${weekStart.year}-W${_getWeekOfYear(weekStart)}';

        final snapshot = await _firestore
            .collection('volunteer_posts')
            .where('communityId', isEqualTo: communityId)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
            .get();

        int weeklyCount = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['joinedUsers'] is List) {
            weeklyCount += (data['joinedUsers'] as List).length;
          }
        }
        weeklyVolunteers[weekKey] = weeklyCount;
      }

      return weeklyVolunteers;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> _getCategoryReports(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('communityId', isEqualTo: communityId)
          .get();

      final Map<String, int> categoryReports = {};
      for (var doc in snapshot.docs) {
        final category = doc.data()['issueType']?.toString() ?? 'Other';
        categoryReports[category] = (categoryReports[category] ?? 0) + 1;
      }

      return categoryReports;
    } catch (e) {
      return {};
    }
  }

  // Helper methods
  Future<String?> _getAdminEmail(String? adminId) async {
    if (adminId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(adminId).get();
      return doc.data()?['email']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getAdminPhone(String? adminId) async {
    if (adminId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(adminId).get();
      return doc.data()?['phoneNumber']?.toString();
    } catch (e) {
      return null;
    }
  }

  String _buildFullAddress(Map<dynamic, dynamic> communityData) {
    final parts = <String>[];

    if (communityData['name'] != null)
      parts.add(communityData['name'].toString());
    if (communityData['municipality'] != null)
      parts.add(communityData['municipality'].toString());
    if (communityData['province'] != null)
      parts.add(communityData['province'].toString());

    return parts.join(', ');
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  // Search and filter methods
  List<BarangayProfile> filterBarangays(
      List<BarangayProfile> profiles, String query) {
    if (query.isEmpty) return profiles;

    final lowercaseQuery = query.toLowerCase();
    return profiles.where((profile) {
      return profile.name.toLowerCase().contains(lowercaseQuery) ||
          profile.adminName.toLowerCase().contains(lowercaseQuery) ||
          profile.municipality.toLowerCase().contains(lowercaseQuery) ||
          profile.province.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  List<BarangayProfile> sortBarangays(
      List<BarangayProfile> profiles, String sortBy) {
    switch (sortBy) {
      case 'name':
        profiles.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'registeredAt':
        profiles.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        break;
      case 'totalUsers':
        profiles.sort((a, b) => b.analytics.totalRegisteredUsers
            .compareTo(a.analytics.totalRegisteredUsers));
        break;
      case 'activeUsers':
        profiles.sort((a, b) => b.analytics.totalActiveUsers
            .compareTo(a.analytics.totalActiveUsers));
        break;
      case 'status':
        profiles.sort((a, b) => a.status.compareTo(b.status));
        break;
      default:
        profiles.sort((a, b) => a.name.compareTo(b.name));
    }
    return profiles;
  }
}
