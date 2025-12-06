import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_user.dart';
import '../models/community.dart';
import '../models/community_notice.dart';
import '../models/firestore_user.dart';
import '../models/report.dart';
import '../services/community_service.dart';
import 'engagement_service.dart';
import 'community_notice_service.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';
import '../pages/admin/deactivated_account_page.dart';
import '../main.dart'; // Import this to access the global navigatorKey
import 'package:rxdart/rxdart.dart';

// Define an enum for admin authentication status
enum AdminAuthStatus {
  authenticated,
  notAdmin,
  deactivated,
}

class AdminAuthResult {
  final AdminAuthStatus status;
  final String? deactivationReason;

  AdminAuthResult({
    required this.status,
    this.deactivationReason,
  });
}

class DeactivationStatus {
  final bool isDeactivated;
  final String? reason;
  final dynamic deactivatedAt;

  DeactivationStatus({
    required this.isDeactivated,
    this.reason,
    this.deactivatedAt,
  });

  DeactivationStatus.active()
      : isDeactivated = false,
        reason = null,
        deactivatedAt = null;

  DeactivationStatus.inactive({String? reason, dynamic timestamp})
      : isDeactivated = true,
        reason = reason,
        deactivatedAt = timestamp;
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _communityService = CommunityService();
  final _storage = FirebaseStorage.instance;
  final EngagementService _engagementService = EngagementService();
  final CommunityNoticeService _noticeService = CommunityNoticeService();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<List<Map<String, dynamic>>> getRTDBUsers() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final adminDoc = await _usersCollection.doc(user.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    final usersSnapshot = await _database.child('users').get();
    if (!usersSnapshot.exists) return [];

    final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
    List<Map<String, dynamic>> communityUsers = [];
    List<String> userIds = [];

    // First pass: Get all users from RTDB
    usersData.forEach((key, value) {
      if (value is Map &&
          value['communityId'] == communityId &&
          value['role'] == 'member') {
        final verificationStatus = value['verificationStatus'] ?? 'pending';

        userIds.add(key);

        String fullName = '';
        if (value['firstName'] != null && value['lastName'] != null) {
          fullName = value['middleName'] != null &&
                  value['middleName'].toString().isNotEmpty
              ? '${value['firstName']} ${value['middleName']} ${value['lastName']}'
              : '${value['firstName']} ${value['lastName']}';
        } else if (value['fullName'] != null) {
          fullName = value['fullName'];
        }

        communityUsers.add({
          'uid': key,
          'fullName': fullName,
          'email': value['email'] ?? '',
          'mobile': value['mobile'] ?? '',
          'address': value['address'] ?? '',
          'barangay': value['location']?['barangay'] ?? '',
          'createdAt':
              DateTime.fromMillisecondsSinceEpoch(value['createdAt'] ?? 0),
          'isActive': value['isActive'] ?? false,
          'verificationStatus': verificationStatus,
          'profileImageUrl': value['profileImageUrl'],
        });
      }
    });

    // Sort by newest first
    communityUsers.sort((a, b) =>
        (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    // This is important to ensure we have the most accurate status
    await _checkAllUsersVerificationStatus(userIds, communityUsers);

    return communityUsers;
  }

  // Helper method to check Firestore for verification statuses for all users
  Future<void> _checkAllUsersVerificationStatus(
      List<String> userIds, List<Map<String, dynamic>> communityUsers) async {
    const batchSize = 10;
    for (var i = 0; i < userIds.length; i += batchSize) {
      final end =
          (i + batchSize < userIds.length) ? i + batchSize : userIds.length;
      final batch = userIds.sublist(i, end);

      await Future.wait(batch.map((userId) async {
        try {
          final userIndex =
              communityUsers.indexWhere((user) => user['uid'] == userId);
          if (userIndex == -1) return; // Skip if user not found in our list

          final userDoc = await _usersCollection.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final verificationStatus =
                userData['verificationStatus'] ?? 'pending';
            final isActive = verificationStatus == 'verified';
            final profileImageUrl = userData['profileImageUrl'];

            communityUsers[userIndex]['verificationStatus'] =
                verificationStatus;
            communityUsers[userIndex]['isActive'] = isActive;

            if (profileImageUrl != null &&
                communityUsers[userIndex]['profileImageUrl'] == null) {
              communityUsers[userIndex]['profileImageUrl'] = profileImageUrl;
            }

            if (communityUsers[userIndex]['verificationStatus'] !=
                    verificationStatus ||
                communityUsers[userIndex]['isActive'] != isActive ||
                (profileImageUrl != null &&
                    communityUsers[userIndex]['profileImageUrl'] == null)) {
              final updates = <String, dynamic>{
                'isActive': isActive,
                'verificationStatus': verificationStatus,
              };

              // Include profile image URL in the update if it exists in Firestore but not in RTDB
              if (profileImageUrl != null &&
                  communityUsers[userIndex]['profileImageUrl'] == null) {
                updates['profileImageUrl'] = profileImageUrl;
              }

              await _database.child('users').child(userId).update(updates);
            }
          }
        } catch (e) {
          // Just log errors but don't interrupt the process
          debugPrint('Firestore verification check error for user $userId: $e');
        }
      }));
    }
  }

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _reportsCollection =>
      _firestore.collection('reports');
  CollectionReference get _volunteerPostsCollection =>
      _firestore.collection('volunteer_posts');
  CollectionReference get _marketItemsCollection =>
      _firestore.collection('market_items');
  CollectionReference get _noticesCollection =>
      _firestore.collection('community_notices');
  CollectionReference get _auditLogsCollection =>
      _firestore.collection('audit_logs');
  CollectionReference get _chatsCollection => _firestore.collection('chats');

  Future<Community?> getCurrentAdminCommunity() async {
    if (_auth.currentUser == null) return null;

    final adminDoc = await _usersCollection.doc(_auth.currentUser!.uid).get();
    if (!adminDoc.exists) return null;

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String?;
    if (communityId == null) return null;

    return _communityService.getCommunity(communityId);
  }

  Future<Map<String, dynamic>> getUserStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final adminDoc = await _usersCollection.doc(user.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    final usersSnapshot = await _database.child('users').get();
    if (!usersSnapshot.exists) {
      return {
        'totalUsers': 0,
        'communityUsers': 0,
        'newUsersThisWeek': 0,
        'pendingUsers': 0,
        'newPendingUsers': 0,
        'pendingUsersTrend': 0
      };
    }

    final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfYesterday =
        DateTime(yesterday.year, yesterday.month, yesterday.day);

    // First collect all users from RTDB
    List<String> communityUserIds = [];
    List<String> allUserIds = [];
    Map<String, DateTime> userCreationDates = {};

    usersData.forEach((key, value) {
      if (value is Map && value['role'] == 'member') {
        allUserIds.add(key);
      }

      if (value is Map &&
          value['communityId'] == communityId &&
          value['role'] != 'admin' &&
          value['role'] != 'super_admin') {
        communityUserIds.add(key);

        final createdAt =
            DateTime.fromMillisecondsSinceEpoch(value['createdAt'] ?? 0);
        userCreationDates[key] = createdAt;
      }
    });

    // Variables to track counts
    int totalUsers = 0;
    int communityUsers = 0;
    int newUsersThisWeek = 0;
    int pendingUsers = 0;
    int pendingUsersToday = 0;
    int pendingUsersYesterday = 0;

    // Now check Firestore for verification status
    const batchSize = 10;
    for (var i = 0; i < communityUserIds.length; i += batchSize) {
      final end = (i + batchSize < communityUserIds.length)
          ? i + batchSize
          : communityUserIds.length;
      final batch = communityUserIds.sublist(i, end);

      await Future.wait(batch.map((userId) async {
        try {
          final userDoc = await _usersCollection.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final verificationStatus =
                userData['verificationStatus'] ?? 'pending';

            if (verificationStatus == 'verified') {
              communityUsers++;
              totalUsers++;

              final createdAt = userCreationDates[userId];
              if (createdAt != null && createdAt.isAfter(lastWeek)) {
                newUsersThisWeek++;
              }
            } else if (verificationStatus == 'pending') {
              pendingUsers++;

              final createdAt = userCreationDates[userId];
              if (createdAt != null) {
                if (createdAt.isAfter(startOfToday) ||
                    createdAt.isAtSameMomentAs(startOfToday)) {
                  pendingUsersToday++;
                }
                else if (createdAt.isAfter(startOfYesterday) ||
                    createdAt.isAtSameMomentAs(startOfYesterday)) {
                  pendingUsersYesterday++;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error checking verification status for user $userId: $e');
        }
      }));
    }

    final pendingUsersTrend = pendingUsersToday - pendingUsersYesterday;

    return {
      'totalUsers': totalUsers,
      'communityUsers': communityUsers,
      'newUsersThisWeek': newUsersThisWeek,
      'pendingUsers': pendingUsers,
      'newPendingUsers': pendingUsersToday,
      'pendingUsersTrend': pendingUsersTrend,
    };
  }

  Future<Map<String, dynamic>> getCommunityStats() async {
    try {
      // Verify admin access first
      if (!await isCurrentUserAdmin()) {
        throw Exception('Permission denied: Only admins can access statistics');
      }

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) throw Exception('Admin not found');

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String?;

      if (communityId == null) {
        // If no community ID is found, return default values
        return {
          'totalCommunities': 1,
          'activeCommunities': 1,
          'inactiveCommunities': 0,
          'membersCount': 0,
          'activeUsers': 0,
          'engagementRate': 25, // Default engagement rate
        };
      }

      final userStats = await getUserStats();
      int communityUsers = userStats['communityUsers'] as int? ?? 0;
      final engagementData =
          await _engagementService.calculateEngagement(communityId);

      final int engagementRate = engagementData['engagementRate'] as int? ?? 40;
      final int activeUsers = engagementData['activeUsers'] as int? ?? 0;
      final int membersCount =
          engagementData['totalMembers'] as int? ?? communityUsers;

      return {
        'totalCommunities': 1, // For a single community admin
        'activeCommunities': 1,
        'inactiveCommunities': 0,
        'membersCount': membersCount,
        'activeUsers': activeUsers,
        'engagementRate': engagementRate,
        'engagementComponents': engagementData['engagementComponents'],
      };
    } catch (e) {
      int communityUsers = 4; // Default
      try {
        final userStats = await getUserStats();
        communityUsers = userStats['communityUsers'] as int? ?? 4;
      } catch (userStatsError) {
        // Continue with default value if there's an error getting user stats
        debugPrint('Error getting user stats: $userStatsError');
      }

      return {
        'totalCommunities': 1,
        'activeCommunities': 1,
        'inactiveCommunities': 0,
        'membersCount': communityUsers, // Use actual community users or default
        'activeUsers': communityUsers > 0 ? 1 : 0,
        'engagementRate': 40, // Default engagement rate
      };
    }
  }

  Future<Map<String, dynamic>> getActivityStats() async {
    try {
      // Verify admin access first
      if (!await isCurrentUserAdmin()) {
        throw Exception('Permission denied: Only admins can access statistics');
      }

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) throw Exception('Admin not found');

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String?;

      if (communityId == null) {
        return {
          'totalReports': 0,
          'volunteerPosts': 0,
          'recentLogs': 0,
          'activeChats': 0,
          'dailyActivity': List<int>.filled(7, 0),
          'newReportsToday': 0,
          'newReportsTrend': 0,
          'newUsersToday': 0,
          'newUsersTrend': 0,
          'newPostsToday': 0,
          'newPostsTrend': 0,
        };
      }

      int activeReportsCount = 0;
      try {
        final reportsQuery = await _reportsCollection
            .where('communityId', isEqualTo: communityId)
            .where('status', whereIn: ['pending', 'in_progress'])
            .count()
            .get();
        activeReportsCount = reportsQuery.count ?? 0;
      } catch (e) {
        // Continue with default value
      }

      int newReportsToday = 0;
      int newReportsYesterday = 0;
      int newReportsTrend = 0;

      final nowUtc = DateTime.now().toUtc(); // Use UTC time
      final startOfToday = DateTime.utc(
          nowUtc.year, nowUtc.month, nowUtc.day); // Start of UTC day
      final startOfTodayTimestamp =
          Timestamp.fromDate(startOfToday); // Firestore Timestamp (UTC based)

      final yesterdayUtc = nowUtc.subtract(const Duration(days: 1));
      final startOfYesterday = DateTime.utc(yesterdayUtc.year,
          yesterdayUtc.month, yesterdayUtc.day); // Start of previous UTC day
      final startOfYesterdayTimestamp = Timestamp.fromDate(
          startOfYesterday); // Firestore Timestamp (UTC based)

      try {
        final todayReportsQuery = await _reportsCollection
            .where('communityId', isEqualTo: communityId)
            .where('createdAt', isGreaterThanOrEqualTo: startOfTodayTimestamp)
            .count()
            .get();
        newReportsToday = todayReportsQuery.count ?? 0;

        final yesterdayReportsQuery = await _reportsCollection
            .where('communityId', isEqualTo: communityId)
            .where('createdAt',
                isGreaterThanOrEqualTo: startOfYesterdayTimestamp)
            .where('createdAt', isLessThan: startOfTodayTimestamp)
            .count()
            .get();
        newReportsYesterday = yesterdayReportsQuery.count ?? 0;

        newReportsTrend = newReportsToday - newReportsYesterday;
      } catch (e) {
        debugPrint('Error calculating reports stats: $e');
      }

      int volunteerPostsCount = 0;
      try {
        final postsQuery = await _volunteerPostsCollection
            .where('communityId', isEqualTo: communityId)
            .count()
            .get();
        volunteerPostsCount = postsQuery.count ?? 0;
      } catch (e) {
        // Continue with default value
      }

      final yesterdayTimestamp =
          Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
      int recentLogsCount = 0;
      try {
        final logsQuery = await _auditLogsCollection
            .where('timestamp', isGreaterThan: yesterdayTimestamp)
            .count()
            .get();
        recentLogsCount = logsQuery.count ?? 0;
      } catch (e) {
        // Continue with default value
      }

      final lastWeek =
          Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      int activeChatsCount = 0;
      try {
        final chatsQuery = await _chatsCollection
            .where('lastMessageAt', isGreaterThan: lastWeek)
            .count()
            .get();
        activeChatsCount = chatsQuery.count ?? 0;
      } catch (e) {
        // Continue with default value
      }

      List<int> dailyActivity;
      try {
        dailyActivity = await _getDailyActivityData(communityId);
      } catch (e) {
        dailyActivity = List<int>.filled(7, 0);
        dailyActivity[1] = 3;
        dailyActivity[3] = 5;
        dailyActivity[5] = 2;
      }

      int newPostsToday = 0;
      int newPostsYesterday = 0;
      int newPostsTrend = 0;

      try {
        final todayVolunteerPostsQuery = await _volunteerPostsCollection
            .where('communityId', isEqualTo: communityId)
            .where('date',
                isGreaterThanOrEqualTo:
                    startOfTodayTimestamp) // Compare with UTC start of day
            .count()
            .get();
        final volunteerPostsToday = todayVolunteerPostsQuery.count ?? 0;
        debugPrint('Volunteer posts today: $volunteerPostsToday');
        newPostsToday = volunteerPostsToday;

        final yesterdayVolunteerPostsQuery = await _volunteerPostsCollection
            .where('communityId', isEqualTo: communityId)
            .where('date',
                isGreaterThanOrEqualTo:
                    startOfYesterdayTimestamp) // Compare with UTC start of yesterday
            .where('date',
                isLessThan:
                    startOfTodayTimestamp) // Compare with UTC start of today
            .count()
            .get();
        final volunteerPostsYesterday = yesterdayVolunteerPostsQuery.count ?? 0;
        debugPrint('Volunteer posts yesterday: $volunteerPostsYesterday');
        newPostsYesterday = volunteerPostsYesterday;

        final noticesSnapshot = await _database
            .child('community_notices')
            .orderByChild('communityId')
            .equalTo(communityId)
            .get();

        if (noticesSnapshot.exists) {
          final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;
          final startOfTodayMillis = startOfToday.millisecondsSinceEpoch;
          final startOfYesterdayMillis =
              startOfYesterday.millisecondsSinceEpoch;

          noticesData.forEach((key, value) {
            if (value is Map) {
              final createdAtMillis = value['createdAt'] as int?;
              if (createdAtMillis != null) {
                if (createdAtMillis >= startOfTodayMillis) {
                  newPostsToday++;
                  debugPrint(
                      'Found community notice from today, total posts today: $newPostsToday');
                } else if (createdAtMillis >= startOfYesterdayMillis &&
                    createdAtMillis < startOfTodayMillis) {
                  newPostsYesterday++;
                  debugPrint(
                      'Found community notice from yesterday, total posts yesterday: $newPostsYesterday');
                }
              }
            }
          });
        }

        newPostsTrend = newPostsToday - newPostsYesterday;
      } catch (e) {
        debugPrint('Error calculating posts stats: $e');
      }

      int newUsersToday = 0;
      int newUsersYesterday = 0;
      int newUsersTrend = 0;

      try {
        // First get all user IDs from RTDB to check their verification status in Firestore
        final usersSnapshot = await _database.child('users').get();
        if (usersSnapshot.exists) {
          final usersData = usersSnapshot.value as Map<dynamic, dynamic>;

          List<Map<String, dynamic>> communityUsers = [];

          // First pass: collect all community users from RTDB
          usersData.forEach((key, value) {
            if (value is Map &&
                value['communityId'] == communityId &&
                value['role'] != 'admin' &&
                value['role'] != 'super_admin') {
              final createdAtMillis = value['createdAt'] as int?;
              if (createdAtMillis == null) return; // Skip if createdAt is null

              final createdAt = DateTime.fromMillisecondsSinceEpoch(
                  createdAtMillis,
                  isUtc: true); // Treat RTDB timestamp as UTC

              communityUsers.add({
                'uid': key,
                'createdAt': createdAt,
              });
            }
          });

          const batchSize = 10;
          for (var i = 0; i < communityUsers.length; i += batchSize) {
            final end = (i + batchSize < communityUsers.length)
                ? i + batchSize
                : communityUsers.length;
            final batch = communityUsers.sublist(i, end);

            await Future.wait(batch.map((userData) async {
              try {
                final userId = userData['uid'];
                final createdAt = userData['createdAt'] as DateTime;

                final userDoc = await _usersCollection.doc(userId).get();
                if (userDoc.exists) {
                  final firestoreData = userDoc.data() as Map<String, dynamic>;
                  final verificationStatus =
                      firestoreData['verificationStatus'] ?? 'pending';

                  // Only count verified users
                  if (verificationStatus == 'verified') {
                    if (createdAt.isAfter(startOfToday) ||
                        createdAt.isAtSameMomentAs(startOfToday)) {
                      newUsersToday++;
                    }
                    else if (createdAt.isAfter(startOfYesterday) ||
                        createdAt.isAtSameMomentAs(startOfYesterday)) {
                      newUsersYesterday++;
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error checking verification status for user: $e');
              }
            }));
          }

          newUsersTrend = newUsersToday - newUsersYesterday;
        }
      } catch (e) {
        // Continue with default values
        debugPrint('Error calculating users trend: $e');
      }

      return {
        'totalReports': activeReportsCount,
        'volunteerPosts': volunteerPostsCount,
        'recentLogs': recentLogsCount,
        'activeChats': activeChatsCount,
        'dailyActivity': dailyActivity,
        'newReportsToday': newReportsToday,
        'newReportsTrend': newReportsTrend,
        'newUsersToday': newUsersToday,
        'newUsersTrend': newUsersTrend,
        'newPostsToday': newPostsToday,
        'newPostsTrend': newPostsTrend,
      };
    } catch (e) {
      return {
        'totalReports': 0,
        'volunteerPosts': 0,
        'recentLogs': 0,
        'activeChats': 0,
        'dailyActivity': List<int>.filled(7, 0),
        'newReportsToday': 0,
        'newReportsTrend': 0,
        'newUsersToday': 0,
        'newUsersTrend': 0,
        'newPostsToday': 0,
        'newPostsTrend': 0,
      };
    }
  }

  Future<List<int>> _getDailyActivityData(String communityId) async {
    final now = DateTime.now();
    final dailyActivity = List<int>.filled(7, 0);

    final startDate = DateTime(now.year, now.month, now.day - 6);
    final startTimestamp = Timestamp.fromDate(startDate);
    final startMillis = startDate.millisecondsSinceEpoch;

    try {
      final reportsQuery = await _reportsCollection
          .where('communityId', isEqualTo: communityId)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .get();

      for (var doc in reportsQuery.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final dayIndex = createdAt.toDate().difference(startDate).inDays;
            if (dayIndex >= 0 && dayIndex < 7) {
              dailyActivity[dayIndex]++;
            }
          }
        } catch (e) {
          // Skip this document if there's an error
        }
      }
    } catch (e) {
      // Continue with empty data for reports
    }

    try {
      final postsQuery = await _volunteerPostsCollection
          .where('communityId', isEqualTo: communityId)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .get();

      for (var doc in postsQuery.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['date'] as Timestamp?;
          if (createdAt != null) {
            final dayIndex = createdAt.toDate().difference(startDate).inDays;
            if (dayIndex >= 0 && dayIndex < 7) {
              dailyActivity[dayIndex]++;
            }
          }
        } catch (e) {
          // Skip this document if there's an error
        }
      }
    } catch (e) {
      // Continue with current data
    }

    try {
      final noticesSnapshot = await _database
          .child('community_notices')
          .orderByChild('communityId')
          .equalTo(communityId)
          .get();

      if (noticesSnapshot.exists) {
        final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;

        noticesData.forEach((key, value) {
          try {
            if (value is Map) {
              final createdAtMillis = value['createdAt'] as int?;
              if (createdAtMillis != null && createdAtMillis >= startMillis) {
                final createdAtDate =
                    DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
                final dayIndex = createdAtDate.difference(startDate).inDays;
                if (dayIndex >= 0 && dayIndex < 7) {
                  dailyActivity[dayIndex]++;
                }
              }
            }
          } catch (e) {
            // Skip this notice if there's an error
          }
        });
      } else {}
    } catch (e) {
      // Continue with current data
    }

    // If we have no activity data, add some sample data to make the chart look realistic
    if (dailyActivity.every((value) => value == 0)) {
      dailyActivity[1] = 3;
      dailyActivity[3] = 5;
      dailyActivity[5] = 2;
    }

    return dailyActivity;
  }

  Future<Map<String, dynamic>> getContentStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }

    final marketItemsCount = (await _marketItemsCollection.count().get()).count;
    final noticesCount = (await _noticesCollection.count().get()).count;

    final lastWeek =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final recentPostsCount = (await _volunteerPostsCollection
            .where('date', isGreaterThan: lastWeek)
            .count()
            .get())
        .count;

    return {
      'marketItems': marketItemsCount,
      'communityNotices': noticesCount,
      'recentPosts': recentPostsCount,
    };
  }

  Stream<AdminUser?> getAdminUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final userData = snapshot.data() as Map<String, dynamic>;
      final role = userData['role'] as String;

      if (role == 'admin' || role == 'super_admin') {
        final userDataWithId = {
          ...userData,
          'uid': snapshot.id,
        };
        return AdminUser.fromMap(userDataWithId);
      }

      return null;
    });
  }

  Future<AdminAuthResult> checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AdminAuthResult(status: AdminAuthStatus.notAdmin);
    }

    bool firebaseStatus = true;
    String? deactivationReason;
    bool needsSyncToRtdb = false;

    // First check Firestore
    final userDoc = await _usersCollection.doc(user.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;

      if (userData['role'] == 'community_admin' ||
          userData['role'] == 'admin' ||
          userData['role'] == 'super_admin') {
        if (userData['status'] == 'inactive') {
          firebaseStatus = false;
          deactivationReason = userData['deactivationReason'] as String?;
        } else {
          // Account is active in Firestore, may need to sync to RTDB
          needsSyncToRtdb = true;
        }
      } else {
        // Not an admin in Firestore
        return AdminAuthResult(status: AdminAuthStatus.notAdmin);
      }
    }

    // If status is active in Firestore but we need to check RTDB
    if (needsSyncToRtdb) {
      try {
        final rtdbSnapshot =
            await _database.child('users').child(user.uid).get();
        if (rtdbSnapshot.exists) {
          final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;

          // If deactivated in RTDB but active in Firestore, sync RTDB to match Firestore
          if (rtdbData['status'] == 'inactive') {
            await _database.child('users').child(user.uid).update({
              'status': 'active',
              'updatedAt': ServerValue.timestamp,
            });
            debugPrint('RTDB admin status synchronized to active');
          }
        }

        return AdminAuthResult(status: AdminAuthStatus.authenticated);
      } catch (e) {
        debugPrint('Error syncing admin status to RTDB: $e');
        // Continue with Firestore status (active)
        return AdminAuthResult(status: AdminAuthStatus.authenticated);
      }
    }

    // If we found it's inactive in Firestore
    if (!firebaseStatus) {
      return AdminAuthResult(
        status: AdminAuthStatus.deactivated,
        deactivationReason: deactivationReason,
      );
    }

    // If not found in Firestore or not an admin there, check RTDB
    try {
      final rtdbSnapshot = await _database.child('users').child(user.uid).get();
      if (rtdbSnapshot.exists) {
        final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;

        if (rtdbData['status'] == 'inactive') {
          // If we have a Firestore record but status doesn't match RTDB, update Firestore
          if (userDoc.exists) {
            // Sync Firestore to match RTDB inactive status
            await _usersCollection.doc(user.uid).update({
              'status': 'inactive',
              'deactivationReason': rtdbData['deactivationReason'],
              'deactivatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('Firestore admin status synchronized to inactive');
          }

          return AdminAuthResult(
            status: AdminAuthStatus.deactivated,
            deactivationReason: rtdbData['deactivationReason'] as String?,
          );
        }

        final role = rtdbData['role'] as String?;
        if (role == 'community_admin' ||
            role == 'admin' ||
            role == 'super_admin') {
          return AdminAuthResult(status: AdminAuthStatus.authenticated);
        }
      }
    } catch (e) {
      debugPrint('Error checking RTDB for admin role: $e');
    }

    return AdminAuthResult(status: AdminAuthStatus.notAdmin);
  }

  // Original method for backwards compatibility
  Future<bool> isCurrentUserAdmin() async {
    final result = await checkAdminStatus();
    return result.status == AdminAuthStatus.authenticated;
  }

  Future<void> createAdmin({
    required String email,
    required String password,
    required String fullName,
    required String communityId,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final adminUser = AdminUser(
      uid: userCredential.user!.uid,
      fullName: fullName,
      email: email,
      communityId: communityId,
      isFirstLogin: true,
      createdAt: DateTime.now(),
      status: 'active',
    );

    await _usersCollection.doc(userCredential.user!.uid).set(adminUser.toMap());
  }

  Future<void> updateAdminFirstLogin({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Verify current password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      // Reauthenticate
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      await _usersCollection.doc(user.uid).update({
        'isFirstLogin': false,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      }
      throw Exception('Error updating password: ${e.message}');
    }
  }

  Future<void> updateAdminStatus(String adminId, String status) async {
    await _usersCollection.doc(adminId).update({
      'status': status,
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // First remove FCM tokens to prevent push notifications after logout
      final notificationService = NotificationService();
      await notificationService.removeUserTokens();

      // Then sign out
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during admin sign out: $e');
      // Still attempt to sign out even if token removal fails
      await _auth.signOut();
    }
  }

  Future<void> updateAdminProfile(
      String adminId, Map<String, dynamic> data) async {
    try {
      // Prepare data for Firestore
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();

      await _usersCollection.doc(adminId).update(firestoreData);

      // If name was updated, update all comments by this admin
      if (data.containsKey('fullName')) {
        final String fullName = data['fullName'] as String;
        final String? profileImageUrl = data['profileImageUrl'] as String?;

        final String adminCommentName = 'Admin $fullName';

        await _noticeService.updateUserCommentsInfo(
            adminId, adminCommentName, profileImageUrl);

        // Also update all community notices by this admin
        // Run this in the background to avoid blocking the UI
        if (_auth.currentUser?.uid == adminId) {
          updateExistingNoticesWithProfileInfo();
        }
      }
    } catch (e) {
      throw Exception('Failed to update admin profile: $e');
    }
  }

  Future<void> deleteAdmin(String adminId) async {
    await _usersCollection.doc(adminId).delete();
  }

  Stream<List<Report>> getReports({String? status}) async* {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access reports');
    }

    final community = await getCurrentAdminCommunity();
    if (community == null) throw Exception('Admin community not found');

    var query = _reportsCollection
        .where('communityId', isEqualTo: community.id)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              Report.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    }).asBroadcastStream();
  }

  Future<Map<String, dynamic>> getReportStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }

    final community = await getCurrentAdminCommunity();
    if (community == null) throw Exception('Admin community not found');

    final stats = {
      'total': 0,
      'pending': 0,
      'in_progress': 0,
      'resolved': 0,
      'rejected': 0,
    };

    // For report types
    final typeDistribution = <String, int>{};

    // For weekly trend
    final weeklyData = List<int>.filled(7, 0);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    debugPrint('Week start date: $weekStart');
    debugPrint('Current date: $now');

    final reportsQuery = await _reportsCollection
        .where('communityId', isEqualTo: community.id)
        .get();

    for (var doc in reportsQuery.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';
      final issueType = data['issueType'] as String? ?? 'Unknown';

      final createdAt = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now();

      stats['total'] = (stats['total'] ?? 0) + 1;
      stats[status] = (stats[status] ?? 0) + 1;

      typeDistribution[issueType] = (typeDistribution[issueType] ?? 0) + 1;

      if (createdAt.isAfter(weekStart)) {
        final dayDiff = createdAt.difference(weekStart).inDays;
        debugPrint(
            'Report created at: $createdAt, day diff from week start: $dayDiff');
        if (dayDiff >= 0 && dayDiff < 7) {
          weeklyData[dayDiff]++;
          debugPrint('Updated weeklyData[$dayDiff] = ${weeklyData[dayDiff]}');
        }
      } else {
        debugPrint(
            'Report created at: $createdAt is before week start: $weekStart');
      }
    }

    double avgResolutionTime = 0;
    int resolvedCount = 0;

    final resolvedReportsQuery = await _reportsCollection
        .where('communityId', isEqualTo: community.id)
        .where('status', isEqualTo: 'resolved')
        .get();

    for (var doc in resolvedReportsQuery.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now();

      final updatedAt = data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now();

      final resolutionTime =
          updatedAt.difference(createdAt).inHours / 24.0; // in days
      avgResolutionTime += resolutionTime;
      resolvedCount++;
    }

    if (resolvedCount > 0) {
      avgResolutionTime /= resolvedCount;
    }

    final result = {
      'statusCounts': stats,
      'typeDistribution': typeDistribution,
      'weeklyData': weeklyData,
      'avgResolutionTime': avgResolutionTime.toStringAsFixed(1),
    };

    debugPrint('Final weeklyData: ${result["weeklyData"]}');
    return result;
  }

  Future<void> updateReportStatus(String reportId, String newStatus,
      {String? resolutionDetails}) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can update reports');
    }

    final reportDoc = await _reportsCollection.doc(reportId).get();
    if (!reportDoc.exists) throw Exception('Report not found');

    final reportData = reportDoc.data() as Map<String, dynamic>;
    final community = await getCurrentAdminCommunity();
    if (community == null) throw Exception('Admin community not found');

    // Verify the report belongs to admin's community
    if (reportData['communityId'] != community.id) {
      throw Exception(
          'Permission denied: Report belongs to a different community');
    }

    final Map<String, dynamic> updates = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'resolved' || newStatus == 'rejected') {
      if (newStatus == 'resolved') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'rejected') {
        updates['rejectedAt'] = FieldValue.serverTimestamp();
      }

      if (resolutionDetails != null && resolutionDetails.isNotEmpty) {
        updates['resolutionDetails'] = resolutionDetails;
      }
    }

    await _reportsCollection.doc(reportId).update(updates);
  }

  Future<void> removeMarketItem(String itemId) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception(
          'Permission denied: Only admins can remove marketplace items');
    }

    final itemDoc = await _marketItemsCollection.doc(itemId).get();
    if (!itemDoc.exists) {
      throw Exception('Marketplace item not found');
    }

    final itemData = itemDoc.data() as Map<String, dynamic>;
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(adminUser.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Verify the item belongs to the admin's community
    if (itemData['communityId'] != communityId) {
      throw Exception(
          'Permission denied: Item belongs to a different community');
    }

    await _marketItemsCollection.doc(itemId).delete();
  }

  // Warn a seller
  Future<void> warnSeller(String sellerId) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can warn sellers');
    }

    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(adminUser.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    final sellerSnapshot = await _database.child('users/$sellerId').get();
    if (!sellerSnapshot.exists) {
      throw Exception('Seller not found');
    }

    final sellerData = sellerSnapshot.value as Map<dynamic, dynamic>;
    if (sellerData['communityId'] != communityId) {
      throw Exception(
          'Permission denied: Seller belongs to a different community');
    }

    final currentWarnings = sellerData['warnings'] ?? 0;
    await _database.child('users/$sellerId').update({
      'warnings': currentWarnings + 1,
      'lastWarningAt': ServerValue.timestamp,
    });
  }

  Future<void> removeVolunteerPost(String postId) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception(
          'Permission denied: Only admins can remove volunteer posts');
    }

    final postDoc = await _volunteerPostsCollection.doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Volunteer post not found');
    }

    final postData = postDoc.data() as Map<String, dynamic>;
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(adminUser.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Verify the post belongs to the admin's community
    if (postData['communityId'] != communityId) {
      throw Exception(
          'Permission denied: Post belongs to a different community');
    }

    await _volunteerPostsCollection.doc(postId).delete();
  }

  Future<List<CommunityNotice>> getNotices() async {
    final community = await getCurrentAdminCommunity();
    if (community == null) return [];

    final snapshot = await _database
        .child('community_notices')
        .orderByChild('communityId')
        .equalTo(community.id)
        .get();

    if (!snapshot.exists) return [];

    final data = snapshot.value;
    if (data is! Map<dynamic, dynamic>) return [];

    final notices = <CommunityNotice>[];

    try {
      final dataMap = data;

      for (var entry in dataMap.entries) {
        try {
          if (entry.value is! Map<dynamic, dynamic>) continue;

          final originalData = entry.value as Map<dynamic, dynamic>;
          final noticeData = {
            'id': entry.key.toString(),
            'title': originalData['title']?.toString() ?? '',
            'content': originalData['content']?.toString() ?? '',
            'authorId': originalData['authorId']?.toString() ?? '',
            'authorName': originalData['authorName']?.toString() ?? '',
            'authorAvatar': originalData['authorAvatar']?.toString(),
            'imageUrl': originalData['imageUrl']?.toString(),
            'imageUrls': originalData['imageUrls'] is List
                ? originalData['imageUrls']
                : null,
            'communityId': originalData['communityId']?.toString() ?? '',
            'createdAt': originalData['createdAt'] ?? 0,
            'updatedAt': originalData['updatedAt'] ?? 0,
            'likes':
                originalData['likes'] is Map ? originalData['likes'] : null,
            'comments': originalData['comments'] is Map
                ? originalData['comments']
                : null,
            'poll': originalData['poll'] is Map ? originalData['poll'] : null,
            'videoUrl': originalData['videoUrl']?.toString(),
            'attachments': originalData['attachments'] is List
                ? originalData['attachments']
                : null,
          };

          final notice = CommunityNotice.fromMap({
            ...noticeData,
            'id': entry.key.toString(),
          });
          notices.add(notice);
        } catch (e) {
          debugPrint('Error parsing notice: ${e.toString()}');
          // Skip this notice and continue with the next one
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error parsing notices: ${e.toString()}');
      return [];
    }

    // Sort by createdAt in descending order
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notices;
  }

  Future<void> createNotice(String title, String content, String? imageUrl,
      {List<String>? imageUrls,
      String? videoUrl,
      Map<String, dynamic>? poll,
      List<Map<String, dynamic>>? attachments}) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can create notices');
    }

    final community = await getCurrentAdminCommunity();
    if (community == null) {
      throw Exception('No community found for current admin');
    }

    final newNoticeRef = _database.child('community_notices').push();

    final List<String>? finalImageUrls =
        imageUrls ?? (imageUrl != null ? [imageUrl] : null);

    // Debug: Print poll data
    print('AdminService.createNotice poll data:');
    print('Poll: $poll');

    await newNoticeRef.set({
      'title': title,
      'content': content,
      'imageUrls': finalImageUrls,
      'videoUrl': videoUrl,
      'poll': poll,
      'attachments': attachments,
      'communityId': community.id,
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
      'authorId': currentUserId,
      'authorName': await () async {
        final user = _auth.currentUser;
        if (user != null) {
          final adminDoc = await _usersCollection.doc(user.uid).get();
          if (adminDoc.exists) {
            final adminData = adminDoc.data() as Map<String, dynamic>;
            return 'Admin ${adminData['fullName']}';
          }
        }
        return 'Admin';
      }(),
      'authorAvatar': await () async {
        final user = _auth.currentUser;
        if (user != null) {
          final adminDoc = await _usersCollection.doc(user.uid).get();
          if (adminDoc.exists) {
            final adminData = adminDoc.data() as Map<String, dynamic>;
            return adminData['profileImageUrl'] as String?;
          }
        }
        return null;
      }(),
      'likes': null,
      'comments': null,
    });
  }

  Future<void> updateNotice(
      String noticeId, String title, String content, String? imageUrl,
      {List<String>? imageUrls,
      String? videoUrl,
      Map<String, dynamic>? poll,
      List<Map<String, dynamic>>? attachments}) async {
    final community = await getCurrentAdminCommunity();
    if (community == null) {
      throw Exception('No community found for current admin');
    }

    final Map<String, dynamic> updates = {
      'title': title,
      'content': content,
      'updatedAt': ServerValue.timestamp,
    };

    if (imageUrls != null) {
      updates['imageUrls'] = imageUrls;
    } else if (imageUrl != null) {
      updates['imageUrls'] = [imageUrl];
    }

    // Always include videoUrl in updates (null or not)
    // This ensures videos can be removed when editing
    updates['videoUrl'] = videoUrl;

    if (poll != null) {
      updates['poll'] = poll;
    }

    if (attachments != null) {
      updates['attachments'] = attachments;
    }

    await _database.child('community_notices').child(noticeId).update(updates);
  }

  Future<void> deleteNotice(String noticeId) async {
    debugPrint('AdminService: Starting deletion of notice: $noticeId');

    final community = await getCurrentAdminCommunity();
    if (community == null) {
      throw Exception('No community found for current admin');
    }

    // First check if the notice exists
    final noticeSnapshot =
        await _database.child('community_notices').child(noticeId).get();
    if (!noticeSnapshot.exists) {
      debugPrint('AdminService: Notice not found: $noticeId');
      throw Exception('Notice not found');
    }

    debugPrint('AdminService: Notice found, proceeding with deletion');

    // Try to delete the notice image if it exists (but don't block on this)
    try {
      await _storage.ref().child('community_notices/$noticeId').delete();
      debugPrint('AdminService: Notice image deleted successfully');
    } catch (e) {
      // Just log the error but continue with notice deletion
      debugPrint('AdminService: Notice image deletion error (continuing): $e');
    }

    final noticeRef = _database.child('community_notices').child(noticeId);

    try {
      // Try set(null) first as it's more reliable in some Firebase versions
      await noticeRef.set(null);
      debugPrint('AdminService: Notice removal command sent using set(null)');

      await Future.delayed(const Duration(milliseconds: 300));

      // Verify deletion was successful
      final verifySnapshot = await noticeRef.get();
      if (verifySnapshot.exists) {
        debugPrint(
            'AdminService: Notice still exists after set(null), trying remove()...');
        // If set(null) wasn't successful, try with remove() method
        await noticeRef.remove();
        await Future.delayed(const Duration(milliseconds: 300));

        // Final verification
        final finalVerifySnapshot = await noticeRef.get();
        if (finalVerifySnapshot.exists) {
          debugPrint(
              'AdminService: Notice still exists after remove() attempt');
          throw Exception('Failed to delete notice after multiple attempts');
        } else {
          debugPrint(
              'AdminService: Notice successfully deleted using remove()');
        }
      } else {
        debugPrint('AdminService: Notice successfully deleted using set(null)');
      }
    } catch (e) {
      debugPrint('AdminService: Error deleting notice: $e');
      throw Exception('Error deleting notice: $e');
    }
  }

  // Toggle notice like
  Future<void> toggleNoticeLike(String noticeId) async {
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    final likesRef = _database
        .child('community_notices')
        .child(noticeId)
        .child('likes')
        .child(currentUserId!);

    final snapshot = await likesRef.get();
    if (snapshot.exists) {
      await likesRef.remove();
    } else {
      await likesRef.set({
        'createdAt': ServerValue.timestamp,
      });
    }
  }

  Future<String> addComment(String noticeId, String content,
      {String? parentCommentId}) async {
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    String adminName = 'Admin';
    String? profileImageUrl;

    final user = _auth.currentUser;
    if (user != null) {
      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (adminDoc.exists) {
        final adminData = adminDoc.data() as Map<String, dynamic>;
        adminName = 'Admin ${adminData['fullName']}';
        profileImageUrl = adminData['profileImageUrl'] as String?;
      }
    }

    // If parentCommentId is provided, add as a reply to that comment
    if (parentCommentId != null) {
      // First, check if the parent comment is itself a reply by looking it up
      final parentCommentSnapshot = await _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(parentCommentId)
          .get();

      String actualParentId = parentCommentId;

      // Debug print the parent comment data if it exists
      if (parentCommentSnapshot.exists) {
        final parentData =
            parentCommentSnapshot.value as Map<dynamic, dynamic>?;
        debugPrint(
            'ADMIN: Parent comment found as top-level comment: $parentCommentId');
        debugPrint('ADMIN: Parent comment data: ${parentData.toString()}');

        final authorName = parentData?['authorName'] as String?;
        if (authorName != null && authorName.startsWith('Admin')) {
          debugPrint(
              'ADMIN IMPORTANT: Parent comment is an admin comment: $authorName');
        }
      }
      // If the parent comment doesn't exist as a top-level comment, it might be a reply
      else {
        debugPrint(
            'ADMIN: Parent comment $parentCommentId not found as top-level comment, searching in replies...');

        // Search for the comment in all replies
        final allCommentsSnapshot = await _database
            .child('community_notices')
            .child(noticeId)
            .child('comments')
            .get();

        if (allCommentsSnapshot.exists) {
          final allComments =
              allCommentsSnapshot.value as Map<dynamic, dynamic>;
          debugPrint(
              'ADMIN: Found ${allComments.length} top-level comments to search through');

          // Iterate through all top-level comments
          for (var commentEntry in allComments.entries) {
            final comment = commentEntry.value as Map<dynamic, dynamic>;
            final commentAuthorName = comment['authorName'] as String?;

            debugPrint('ADMIN: Checking comment by: $commentAuthorName');

            if (comment['replies'] is Map) {
              final replies = comment['replies'] as Map<dynamic, dynamic>;
              debugPrint('ADMIN: Comment has ${replies.length} replies');

              if (replies.containsKey(parentCommentId)) {
                // Found the actual parent comment
                actualParentId = commentEntry.key.toString();
                debugPrint(
                    'ADMIN: Found actual parent comment: $actualParentId for reply: $parentCommentId');

                if (commentAuthorName != null &&
                    commentAuthorName.startsWith('Admin')) {
                  debugPrint(
                      'ADMIN IMPORTANT: Actual parent comment is an admin comment: $commentAuthorName');
                }

                break;
              }
            }
          }
        }
      }

      // Debug print to help diagnose issues
      debugPrint(
          'Adding reply to comment: $actualParentId, Content: "$content"');

      final newReplyRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(actualParentId)
          .child('replies')
          .push();

      // Debug print to help diagnose issues
      debugPrint(
          'ADMIN: Setting reply data - parentId: $actualParentId, replyToId: $parentCommentId');

      // Always store the replyToId, even if it's the same as the parentId
      // This is important for replies to admin comments
      await newReplyRef.set({
        'content': content,
        'createdAt': ServerValue.timestamp,
        'authorId': currentUserId,
        'authorName': adminName,
        'authorAvatar': profileImageUrl,
        'parentId': actualParentId,
        'replyToId': parentCommentId, // Always store who we're replying to
      });

      return newReplyRef.key!;
    } else {
      final newCommentRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .push();

      await newCommentRef.set({
        'content': content,
        'createdAt': ServerValue.timestamp,
        'authorId': currentUserId,
        'authorName': adminName,
        'authorAvatar': profileImageUrl,
      });

      return newCommentRef.key!;
    }
  }

  Future<void> deleteComment(String noticeId, String commentId,
      {String? parentCommentId}) async {
    if (parentCommentId != null) {
      await _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(parentCommentId)
          .child('replies')
          .child(commentId)
          .remove();
    } else {
      await _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(commentId)
          .remove();
    }
  }

  // Like or unlike a comment
  Future<void> likeComment(String noticeId, String commentId,
      {String? parentCommentId}) async {
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    final DatabaseReference likesRef;

    if (parentCommentId != null) {
      // Like a reply
      likesRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(parentCommentId)
          .child('replies')
          .child(commentId)
          .child('likes')
          .child(currentUserId!);
    } else {
      // Like a top-level comment
      likesRef = _database
          .child('community_notices')
          .child(noticeId)
          .child('comments')
          .child(commentId)
          .child('likes')
          .child(currentUserId!);
    }

    final snapshot = await likesRef.get();
    if (snapshot.exists) {
      // Unlike if already liked
      await likesRef.remove();
    } else {
      // Like if not already liked
      await likesRef.set({
        'createdAt': ServerValue.timestamp,
      });
    }
  }

  Future<QuerySnapshot> getMarketItems(String communityId) async {
    return _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt', descending: true)
        .get();
  }

  Future<QuerySnapshot> getPendingMarketItems(String communityId) async {
    return _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
  }

  // Approve a marketplace item
  Future<void> approveMarketItem(String itemId) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception(
          'Permission denied: Only admins can approve marketplace items');
    }

    final itemDoc = await _marketItemsCollection.doc(itemId).get();
    if (!itemDoc.exists) {
      throw Exception('Marketplace item not found');
    }

    final itemData = itemDoc.data() as Map<String, dynamic>;
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(adminUser.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Verify the item belongs to the admin's community
    if (itemData['communityId'] != communityId) {
      throw Exception(
          'Permission denied: Item belongs to a different community');
    }

    await _marketItemsCollection.doc(itemId).update({
      'status': 'approved',
      'approvedBy': adminUser.uid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reject a marketplace item
  Future<void> rejectMarketItem(String itemId, String rejectionReason) async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception(
          'Permission denied: Only admins can reject marketplace items');
    }

    final itemDoc = await _marketItemsCollection.doc(itemId).get();
    if (!itemDoc.exists) {
      throw Exception('Marketplace item not found');
    }

    final itemData = itemDoc.data() as Map<String, dynamic>;
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(adminUser.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Verify the item belongs to the admin's community
    if (itemData['communityId'] != communityId) {
      throw Exception(
          'Permission denied: Item belongs to a different community');
    }

    await _marketItemsCollection.doc(itemId).update({
      'status': 'rejected',
      'rejectionReason': rejectionReason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getMarketStats(String communityId) async {
    final snapshot = await _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .get();

    int totalItems = 0;
    int activeItems = 0;
    int soldItems = 0;
    double totalValue = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalItems++;
      if (data['isSold'] == true) {
        soldItems++;
        totalValue += (data['price'] as num).toDouble();
      } else {
        activeItems++;
      }
    }

    return {
      'totalItems': totalItems,
      'activeItems': activeItems,
      'soldItems': soldItems,
      'totalValue': totalValue,
      'averagePrice': totalItems > 0 ? totalValue / totalItems : 0,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions(
      String communityId) async {
    debugPrint(
        'AdminService.getRecentTransactions called for community: $communityId');

    final snapshot = await _marketItemsCollection
        .where('communityId', isEqualTo: communityId)
        .where('isSold', isEqualTo: true)
        .orderBy('soldAt', descending: true)
        .limit(5)
        .get();

    debugPrint('Found ${snapshot.docs.length} recent transactions');

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Debug info for each transaction
      debugPrint('Transaction details for item: ${data['title']}');
      debugPrint('  - ID: ${doc.id}');
      debugPrint('  - Price: ${data['price']}');
      debugPrint('  - soldAt: ${data['soldAt']}');
      if (data['soldAt'] != null) {
        final soldAt = (data['soldAt'] as Timestamp).toDate();
        debugPrint('  - soldAt (converted): $soldAt');
      }
      debugPrint('  - createdAt: ${data['createdAt']}');
      if (data['createdAt'] != null) {
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        debugPrint('  - createdAt (converted): $createdAt');
      }

      List<String> imageUrls = [];
      if (data['imageUrls'] != null) {
        // New format with multiple images
        imageUrls = List<String>.from(data['imageUrls']);
      } else if (data['imageUrl'] != null &&
          data['imageUrl'].toString().isNotEmpty) {
        // Old format with single image
        imageUrls = [data['imageUrl']];
      }

      // Determine which date to use
      final date = data['soldAt'] ?? data['createdAt'];
      debugPrint('  - Using date: $date');
      if (date != null) {
        final convertedDate = (date as Timestamp).toDate();
        debugPrint('  - Date (converted): $convertedDate');
      }

      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'imageUrls': imageUrls,
        'amount': data['price'] ?? 0,
        'date': date,
      };
    }).toList();
  }

  Future<List<FirestoreUser>> getPendingVerificationUsers() async {
    debugPrint('===== GETTING PENDING AND REJECTED USERS =====');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) {
        throw Exception('Admin not found');
      }

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String;

      debugPrint('Getting pending users for community: $communityId');

      // First check Firestore for pending and rejected users - this is the source of truth
      final firestoreUsers = await _usersCollection
          .where('communityId', isEqualTo: communityId)
          .where('role', isEqualTo: 'member')
          .where('verificationStatus', whereIn: ['pending', 'rejected']).get();

      List<FirestoreUser> pendingUsers = [];
      Set<String> pendingUserIds = {}; // To track users we've already added

      debugPrint(
          'Found ${firestoreUsers.docs.length} pending/rejected users in Firestore');

      for (var doc in firestoreUsers.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final uid = userData['uid'] ?? doc.id;
        final status = userData['verificationStatus'] ?? 'pending';
        debugPrint('Processing Firestore user $uid with status: $status');

        try {
          final firestoreUser = FirestoreUser.fromMap(userData);
          pendingUsers.add(firestoreUser);
          pendingUserIds.add(uid);
          debugPrint(
              'Added user from Firestore: ${firestoreUser.fullName}, status: ${firestoreUser.verificationStatus}');
        } catch (e) {
          debugPrint('Error creating FirestoreUser from Firestore data: $e');
        }
      }

      // We no longer need to check RTDB since we're using Firestore as the source of truth
      // This is just for logging purposes
      final usersSnapshot = await _database.child('users').get();

      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
        debugPrint('Found ${usersData.length} total users in RTDB');

        // Just log RTDB users for debugging
        for (var entry in usersData.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is Map &&
              value['communityId'] == communityId &&
              value['role'] == 'member') {
            final verificationStatus = value['verificationStatus'];
            final isActive = value['isActive'] ?? false;

            // A user is pending or rejected if:
            // 1. verificationStatus is explicitly 'pending' or 'rejected', OR
            // 2. verificationStatus is null AND isActive is false AND they have a registrationId (meaning they registered but haven't been verified)
            final hasRegistrationId = value['registrationId'] != null &&
                value['registrationId'].toString().isNotEmpty;
            final isPendingOrRejected = verificationStatus == 'pending' ||
                verificationStatus == 'rejected' ||
                (verificationStatus == null && !isActive && hasRegistrationId);

            debugPrint(
                'User ${value['fullName'] ?? key}: verificationStatus=$verificationStatus, isActive=$isActive, hasRegistrationId=$hasRegistrationId, isPendingOrRejected=$isPendingOrRejected');
          }
        }
      }

      // We no longer need to check Firestore separately since we already did that first
      // But we'll keep this method for backward compatibility
      // _checkFirestoreForPendingUsers(communityId, pendingUsers, pendingUserIds);

      return pendingUsers;
    } catch (e) {
      debugPrint('ERROR getting pending verification users: $e');
      rethrow;
    }
  }

  // This method has been removed as we now use Firestore as the source of truth

  Future<FirestoreUser?> getUserByRegistrationId(String registrationId) async {
    debugPrint('===== GETTING USER BY REGISTRATION ID =====');
    debugPrint('Registration ID: $registrationId');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('ERROR: No user logged in');
        throw Exception('No user logged in');
      }
      debugPrint('Admin ID: ${user.uid}');

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) {
        debugPrint('ERROR: Admin document not found');
        throw Exception('Admin not found');
      }
      debugPrint('Admin document found');

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String;
      debugPrint('Admin community ID: $communityId');

      debugPrint('Querying Firestore for user with registration ID...');
      final usersQuery = await _usersCollection
          .where('communityId', isEqualTo: communityId)
          .where('registrationId', isEqualTo: registrationId)
          .where('verificationStatus', whereIn: ['pending', 'rejected'])
          .limit(1)
          .get();

      debugPrint('Query completed. Found ${usersQuery.docs.length} users');

      if (usersQuery.docs.isEmpty) {
        debugPrint('No user found with this registration ID');
        return null;
      }

      final userData = usersQuery.docs.first.data() as Map<String, dynamic>;
      debugPrint('User found: ${userData['fullName']} (${userData['uid']})');

      final foundUser = FirestoreUser.fromMap(userData);
      debugPrint('===== USER RETRIEVED SUCCESSFULLY =====');
      return foundUser;
    } catch (e) {
      debugPrint('ERROR getting user by registration ID: $e');
      rethrow;
    }
  }

  Future<void> updateUserVerificationStatus(
      String userId, String verificationStatus,
      {String? rejectionReason}) async {
    debugPrint('===== UPDATING USER VERIFICATION STATUS =====');
    debugPrint('User ID: $userId');
    debugPrint('New status: $verificationStatus');
    try {
      debugPrint('===== STARTING USER VERIFICATION PROCESS =====');
      debugPrint('User ID: $userId');
      debugPrint('New status: $verificationStatus');

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('ERROR: No user logged in');
        throw Exception('No user logged in');
      }
      debugPrint('Admin ID: ${user.uid}');

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) {
        debugPrint('ERROR: Admin document not found in Firestore');
        throw Exception('Admin not found');
      }
      debugPrint('Admin document found in Firestore');

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String;
      debugPrint('Admin community ID: $communityId');

      // Verify user belongs to admin's community
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('ERROR: User document not found in Firestore');
        throw Exception('User not found');
      }
      debugPrint('User document found in Firestore');

      final userData = userDoc.data() as Map<String, dynamic>;
      debugPrint('User community ID: ${userData['communityId']}');
      if (userData['communityId'] != communityId) {
        debugPrint('ERROR: User belongs to a different community');
        throw Exception(
            'Permission denied: User belongs to a different community');
      }

      debugPrint('Updating user verification status in Firestore...');
      try {
        final Map<String, dynamic> updateData = {
          'verificationStatus': verificationStatus,
          'verifiedAt': verificationStatus == 'verified'
              ? FieldValue.serverTimestamp()
              : null,
          'verifiedBy': verificationStatus == 'verified' ? user.uid : null,
        };

        if (verificationStatus == 'rejected' && rejectionReason != null) {
          updateData['rejectionReason'] = rejectionReason;
          updateData['rejectedAt'] = FieldValue.serverTimestamp();
          updateData['rejectedBy'] = user.uid;
          debugPrint('Adding rejection reason: $rejectionReason');
        }

        await _usersCollection.doc(userId).update(updateData);
        debugPrint('Firestore update successful');
      } catch (firestoreError) {
        debugPrint('ERROR updating Firestore: $firestoreError');
        throw Exception('Failed to update user in Firestore: $firestoreError');
      }

      debugPrint('Updating user verification status in RTDB...');
      try {
        final isActive = verificationStatus == 'verified';
        final Map<String, dynamic> updateData = {
          'isActive': isActive,
          'verificationStatus': verificationStatus,
        };

        if (verificationStatus == 'verified') {
          updateData['verifiedAt'] = ServerValue.timestamp;
        } else if (verificationStatus == 'rejected' &&
            rejectionReason != null) {
          updateData['rejectedAt'] = ServerValue.timestamp;
          updateData['rejectionReason'] = rejectionReason;
        }

        await _database.child('users').child(userId).update(updateData);
        debugPrint('RTDB update successful');
      } catch (rtdbError) {
        debugPrint('ERROR updating RTDB: $rtdbError');
        // Don't throw here, as Firestore is our source of truth for verification
        // Just log the error and continue

        // Since we might have permission issues with RTDB, we need to make sure
        // our UI reflects the correct status from Firestore
        debugPrint('RTDB update failed, but Firestore update was successful.');
        debugPrint('The UI will reflect the correct status on next refresh.');
      }

      debugPrint('Adding audit log...');
      final Map<String, dynamic> auditDetails = {
        'verificationStatus': verificationStatus,
      };

      if (verificationStatus == 'rejected' && rejectionReason != null) {
        auditDetails['rejectionReason'] = rejectionReason;
      }

      await _auditLogsCollection.add({
        'adminId': user.uid,
        'userId': userId,
        'action': 'user_verification_update',
        'details': auditDetails,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Audit log added successfully');
      debugPrint('===== USER VERIFICATION PROCESS COMPLETED =====');
    } catch (e) {
      debugPrint('CRITICAL ERROR in updateUserVerificationStatus: $e');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  Future<void> updateExistingNoticesWithProfileInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final adminDoc = await _usersCollection.doc(user.uid).get();
      if (!adminDoc.exists) throw Exception('Admin not found');

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final communityId = adminData['communityId'] as String;
      final profileImageUrl = adminData['profileImageUrl'] as String?;
      final fullName = adminData['fullName'] as String?;

      // If no profile info to update, return early
      if (profileImageUrl == null && fullName == null) return;

      // Format the admin name with "Admin " prefix
      final adminName = fullName != null ? 'Admin $fullName' : null;

      final noticesSnapshot = await _database
          .child('community_notices')
          .orderByChild('communityId')
          .equalTo(communityId)
          .get();

      if (!noticesSnapshot.exists) return;

      final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;

      for (var entry in noticesData.entries) {
        try {
          if (entry.value is! Map<dynamic, dynamic>) continue;

          final noticeData = entry.value as Map<dynamic, dynamic>;
          final noticeAuthorId = noticeData['authorId']?.toString();
          final noticeId = entry.key.toString();

          // Only update notices by this admin
          if (noticeAuthorId == user.uid) {
            final updates = <String, dynamic>{};

            // Always update profile picture if available
            if (profileImageUrl != null) {
              updates['authorAvatar'] = profileImageUrl;
            }

            if (adminName != null && noticeData['authorName'] != adminName) {
              updates['authorName'] = adminName;
            }

            // Only update if there are changes to make
            if (updates.isNotEmpty) {
              await _database
                  .child('community_notices')
                  .child(noticeId)
                  .update(updates);
              debugPrint('Updated profile info for notice: $noticeId');
            }
          }

          if (noticeData['comments'] is Map) {
            final commentsData =
                noticeData['comments'] as Map<dynamic, dynamic>;

            for (var commentEntry in commentsData.entries) {
              try {
                if (commentEntry.value is! Map<dynamic, dynamic>) continue;

                final commentData = commentEntry.value as Map<dynamic, dynamic>;
                final commentAuthorId = commentData['authorId']?.toString();
                final commentId = commentEntry.key.toString();

                // Only update comments by this admin
                if (commentAuthorId == user.uid) {
                  final commentUpdates = <String, dynamic>{};

                  // Always update profile picture if available
                  if (profileImageUrl != null) {
                    commentUpdates['authorAvatar'] = profileImageUrl;
                  }

                  if (adminName != null &&
                      commentData['authorName'] != adminName) {
                    commentUpdates['authorName'] = adminName;
                  }

                  // Only update if there are changes to make
                  if (commentUpdates.isNotEmpty) {
                    await _database
                        .child('community_notices')
                        .child(noticeId)
                        .child('comments')
                        .child(commentId)
                        .update(commentUpdates);
                    debugPrint(
                        'Updated profile info for comment: $commentId in notice: $noticeId');
                  }
                }

                if (commentData['replies'] is Map) {
                  final repliesData =
                      commentData['replies'] as Map<dynamic, dynamic>;

                  for (var replyEntry in repliesData.entries) {
                    try {
                      if (replyEntry.value is! Map<dynamic, dynamic>) continue;

                      final replyData =
                          replyEntry.value as Map<dynamic, dynamic>;
                      final replyAuthorId = replyData['authorId']?.toString();
                      final replyId = replyEntry.key.toString();

                      // Only update replies by this admin
                      if (replyAuthorId == user.uid) {
                        final replyUpdates = <String, dynamic>{};

                        // Always update profile picture if available
                        if (profileImageUrl != null) {
                          replyUpdates['authorAvatar'] = profileImageUrl;
                        }

                        if (adminName != null &&
                            replyData['authorName'] != adminName) {
                          replyUpdates['authorName'] = adminName;
                        }

                        // Only update if there are changes to make
                        if (replyUpdates.isNotEmpty) {
                          await _database
                              .child('community_notices')
                              .child(noticeId)
                              .child('comments')
                              .child(commentId)
                              .child('replies')
                              .child(replyId)
                              .update(replyUpdates);
                          debugPrint(
                              'Updated profile info for reply: $replyId in comment: $commentId in notice: $noticeId');
                        }
                      }
                    } catch (e) {
                      debugPrint('Error updating reply ${replyEntry.key}: $e');
                      // Continue with other replies even if one fails
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error updating comment ${commentEntry.key}: $e');
                // Continue with other comments even if one fails
              }
            }
          }
        } catch (e) {
          debugPrint('Error updating notice ${entry.key}: $e');
          // Continue with other notices even if one fails
        }
      }

      debugPrint(
          'Finished updating existing notices and comments with profile information');
    } catch (e) {
      debugPrint('Error updating existing notices and comments: $e');
      // Don't throw, as this is a background operation that shouldn't interrupt the UI
    }
  }

  // Alias for backward compatibility
  Future<void> updateExistingNoticesWithProfilePicture() async {
    return updateExistingNoticesWithProfileInfo();
  }

  Future<Map<String, dynamic>?> isCurrentUserDeactivated() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      bool needsRtdbUpdate = false;
      bool needsFirestoreUpdate = false;
      String? deactivationReason;
      dynamic deactivatedAt;

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['status'] == 'inactive') {
          deactivationReason = userData['deactivationReason'] as String?;
          deactivatedAt = userData['deactivatedAt'] as Timestamp?;
          return {
            'deactivated': true,
            'reason': deactivationReason,
            'deactivatedAt': deactivatedAt,
          };
        } else {
          // Account is active in Firestore
          needsRtdbUpdate = true;
        }
      }

      final rtdbSnapshot = await _database.child('users').child(user.uid).get();
      if (rtdbSnapshot.exists) {
        final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;
        if (rtdbData['status'] == 'inactive') {
          // If Firestore shows active but RTDB shows inactive, sync them
          if (needsRtdbUpdate) {
            await _database.child('users').child(user.uid).update({
              'status': 'active',
              'updatedAt': ServerValue.timestamp,
            });
            debugPrint('Synchronized RTDB admin status to active');
            return {'deactivated': false};
          }

          deactivationReason = rtdbData['deactivationReason'] as String?;
          deactivatedAt = rtdbData['deactivatedAt'] as int?;

          // If Firestore record exists but doesn't match RTDB inactive status, update it
          if (userDoc.exists) {
            needsFirestoreUpdate = true;
          }

          return {
            'deactivated': true,
            'reason': deactivationReason,
            'deactivatedAt': deactivatedAt,
          };
        } else if (needsFirestoreUpdate) {
          // RTDB is active but Firestore might need update (already handled above)
          return {'deactivated': false};
        }
      }

      return {'deactivated': false};
    } catch (e) {
      debugPrint('Error checking if user is deactivated: $e');
      return null;
    }
  }

  // Stream that monitors admin deactivation status in real-time
  Stream<DeactivationStatus> streamDeactivationStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(DeactivationStatus.active());
    }

    // Listen for Firestore changes
    return _usersCollection
        .doc(user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        if (snapshot.exists) {
          final userData = snapshot.data() as Map<String, dynamic>;
          if (userData['status'] == 'inactive') {
            return DeactivationStatus.inactive(
              reason: userData['deactivationReason'] as String?,
              timestamp: userData['deactivatedAt'],
            );
          }
        }

        // If not deactivated in Firestore, check RTDB as well
        final rtdbSnapshot =
            await _database.child('users').child(user.uid).get();
        if (rtdbSnapshot.exists) {
          final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;
          if (rtdbData['status'] == 'inactive') {
            return DeactivationStatus.inactive(
              reason: rtdbData['deactivationReason'] as String?,
              timestamp: rtdbData['deactivatedAt'],
            );
          }
        }

        // Not deactivated in either database
        return DeactivationStatus.active();
      } catch (e) {
        debugPrint('Error in deactivation stream: $e');
        // On error, assume not deactivated to prevent false positives
        return DeactivationStatus.active();
      }
    });
  }
}
