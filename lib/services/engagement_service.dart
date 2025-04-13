import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EngagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Cache for user roles to reduce database queries
  final Map<String, String> _userRoleCache = {};

  // Collection references
  final CollectionReference _usersCollection;
  final CollectionReference _noticesCollection;
  final CollectionReference _volunteerPostsCollection;
  final CollectionReference _marketItemsCollection;
  final CollectionReference _reportsCollection;
  final CollectionReference _communitiesCollection;
  final DatabaseReference _chatsRef;

  // Constructor with collection initialization
  EngagementService()
      : _usersCollection = FirebaseFirestore.instance.collection('users'),
        _noticesCollection =
            FirebaseFirestore.instance.collection('community_notices'),
        _volunteerPostsCollection =
            FirebaseFirestore.instance.collection('volunteer_posts'),
        _marketItemsCollection =
            FirebaseFirestore.instance.collection('market_items'),
        _reportsCollection = FirebaseFirestore.instance.collection('reports'),
        _communitiesCollection =
            FirebaseFirestore.instance.collection('communities'),
        _chatsRef = FirebaseDatabase.instance.ref().child('chats');

  // Check if current user is admin with caching
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check cache first
      if (_userRoleCache.containsKey(user.uid)) {
        final role = _userRoleCache[user.uid];
        return role == 'admin' || role == 'super_admin';
      }

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String;

      // Cache the result
      _userRoleCache[user.uid] = role;

      return role == 'admin' || role == 'super_admin';
    } catch (e) {
      return false;
    }
  }

  // Get user role with caching
  Future<String?> _getUserRole(String userId) async {
    try {
      // Check cache first
      if (_userRoleCache.containsKey(userId)) {
        return _userRoleCache[userId];
      }

      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String;

      // Cache the result
      _userRoleCache[userId] = role;

      return role;
    } catch (e) {
      return null;
    }
  }

  // Check if a user is admin with caching
  Future<bool> _isUserAdmin(String userId) async {
    final role = await _getUserRole(userId);
    return role == 'admin' || role == 'super_admin';
  }

  // Calculate community engagement metrics
  Future<Map<String, dynamic>> calculateEngagement(String communityId) async {
    try {
      if (communityId.isEmpty) {
        throw Exception('Community ID is required');
      }

      // Get member count for the community
      int membersCount = 0;
      try {
        final communityDoc =
            await _communitiesCollection.doc(communityId).get();
        if (communityDoc.exists) {
          final communityData = communityDoc.data() as Map<String, dynamic>;
          membersCount = communityData['membersCount'] as int? ?? 0;
        }

        // If we can't get from community doc, try counting verified users only
        if (membersCount == 0) {
          final usersQuery = await _usersCollection
              .where('communityId', isEqualTo: communityId)
              .where('role', whereIn: ['member', 'user'])
              .where('verificationStatus', isEqualTo: 'verified')
              .count()
              .get();
          membersCount = usersQuery.count ?? 0;
        }
      } catch (e) {
        membersCount = 4; // Default value
      }

      // Calculate engagement metrics for different time periods
      final now = DateTime.now();
      final lastDay = now.subtract(const Duration(days: 1));
      final lastWeek = now.subtract(const Duration(days: 7));
      final lastMonth = now.subtract(const Duration(days: 30));

      // Initialize engagement components with weights
      final engagementWeights = {
        'userLikesComments': 0.25, // 25% weight for user interactions
        'volunteerParticipation': 0.20, // 20% weight for volunteer activities
        'marketplaceActivity': 0.15, // 15% weight for marketplace engagement
        'reportSubmissions': 0.15, // 15% weight for community reporting
        'chatActivity': 0.15, // 15% weight for chat engagement
        'adminInteractions': 0.10, // 10% weight for admin responsiveness
      };

      Map<String, int> engagementComponents = {
        'userLikesComments': 0,
        'volunteerParticipation': 0,
        'marketplaceActivity': 0,
        'reportSubmissions': 0,
        'chatActivity': 0,
        'adminInteractions': 0,
      };

      // Track activity recency
      Map<String, int> recentActivity = {
        'lastDay': 0,
        'lastWeek': 0,
        'lastMonth': 0,
      };

      // 1. USER INTERACTIONS (Likes and Comments)
      try {
        final noticesSnapshot = await _database
            .ref()
            .child('community_notices')
            .orderByChild('communityId')
            .equalTo(communityId)
            .get();

        if (noticesSnapshot.exists) {
          final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;
          int totalInteractions = 0;
          int recentDayInteractions = 0;
          int recentWeekInteractions = 0;
          int recentMonthInteractions = 0;

          noticesData.forEach((key, value) {
            if (value is Map) {
              // Count likes
              if (value['likes'] is Map) {
                final likes = value['likes'] as Map;
                totalInteractions += likes.length;

                // Check recency
                likes.forEach((_, likeData) {
                  if (likeData is Map && likeData['timestamp'] != null) {
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                        likeData['timestamp']);
                    if (timestamp.isAfter(lastDay)) recentDayInteractions++;
                    if (timestamp.isAfter(lastWeek)) recentWeekInteractions++;
                    if (timestamp.isAfter(lastMonth)) recentMonthInteractions++;
                  }
                });
              }

              // Count comments
              if (value['comments'] is Map) {
                final comments = value['comments'] as Map;
                totalInteractions += comments.length;

                // Check recency
                comments.forEach((_, commentData) {
                  if (commentData is Map && commentData['timestamp'] != null) {
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                        commentData['timestamp']);
                    if (timestamp.isAfter(lastDay)) recentDayInteractions++;
                    if (timestamp.isAfter(lastWeek)) recentWeekInteractions++;
                    if (timestamp.isAfter(lastMonth)) recentMonthInteractions++;
                  }
                });
              }
            }
          });

          engagementComponents['userLikesComments'] = totalInteractions;
          recentActivity['lastDay'] =
              (recentActivity['lastDay'] ?? 0) + recentDayInteractions;
          recentActivity['lastWeek'] =
              (recentActivity['lastWeek'] ?? 0) + recentWeekInteractions;
          recentActivity['lastMonth'] =
              (recentActivity['lastMonth'] ?? 0) + recentMonthInteractions;
        }
      } catch (e) {
        // Continue with other metrics
      }

      // 2. VOLUNTEER PARTICIPATION
      try {
        final postsQuery = await _volunteerPostsCollection
            .where('communityId', isEqualTo: communityId)
            .get();

        int totalParticipation = 0;
        int recentDayParticipation = 0;
        int recentWeekParticipation = 0;
        int recentMonthParticipation = 0;

        for (var doc in postsQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['joinedUsers'] is List) {
            final signups = (data['joinedUsers'] as List).length;
            totalParticipation += signups;

            final eventDate = (data['date'] as Timestamp).toDate();
            if (eventDate.isAfter(lastDay)) recentDayParticipation += signups;
            if (eventDate.isAfter(lastWeek)) recentWeekParticipation += signups;
            if (eventDate.isAfter(lastMonth))
              recentMonthParticipation += signups;
          }
        }

        engagementComponents['volunteerParticipation'] = totalParticipation;
        recentActivity['lastDay'] =
            (recentActivity['lastDay'] ?? 0) + recentDayParticipation;
        recentActivity['lastWeek'] =
            (recentActivity['lastWeek'] ?? 0) + recentWeekParticipation;
        recentActivity['lastMonth'] =
            (recentActivity['lastMonth'] ?? 0) + recentMonthParticipation;
      } catch (e) {
        // Continue with other metrics
      }

      // 3. MARKETPLACE ACTIVITY
      try {
        final marketQuery = await _marketItemsCollection
            .where('communityId', isEqualTo: communityId)
            .where('createdAt', isGreaterThan: lastMonth)
            .get();

        int totalMarketActivity = 0;
        int recentDayMarket = 0;
        int recentWeekMarket = 0;
        int recentMonthMarket = 0;

        for (var doc in marketQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalMarketActivity++;

          final createdAt = (data['createdAt'] as Timestamp).toDate();
          if (createdAt.isAfter(lastDay)) recentDayMarket++;
          if (createdAt.isAfter(lastWeek)) recentWeekMarket++;
          if (createdAt.isAfter(lastMonth)) recentMonthMarket++;
        }

        engagementComponents['marketplaceActivity'] = totalMarketActivity;
        recentActivity['lastDay'] =
            (recentActivity['lastDay'] ?? 0) + recentDayMarket;
        recentActivity['lastWeek'] =
            (recentActivity['lastWeek'] ?? 0) + recentWeekMarket;
        recentActivity['lastMonth'] =
            (recentActivity['lastMonth'] ?? 0) + recentMonthMarket;
      } catch (e) {
        // Continue with other metrics
      }

      // 4. REPORT SUBMISSIONS
      try {
        final reportsQuery = await _reportsCollection
            .where('communityId', isEqualTo: communityId)
            .where('submittedAt', isGreaterThan: lastMonth)
            .get();

        int totalReports = 0;
        int recentDayReports = 0;
        int recentWeekReports = 0;
        int recentMonthReports = 0;

        for (var doc in reportsQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalReports++;

          final submittedAt = (data['submittedAt'] as Timestamp).toDate();
          if (submittedAt.isAfter(lastDay)) recentDayReports++;
          if (submittedAt.isAfter(lastWeek)) recentWeekReports++;
          if (submittedAt.isAfter(lastMonth)) recentMonthReports++;
        }

        engagementComponents['reportSubmissions'] = totalReports;
        recentActivity['lastDay'] =
            (recentActivity['lastDay'] ?? 0) + recentDayReports;
        recentActivity['lastWeek'] =
            (recentActivity['lastWeek'] ?? 0) + recentWeekReports;
        recentActivity['lastMonth'] =
            (recentActivity['lastMonth'] ?? 0) + recentMonthReports;
      } catch (e) {
        // Continue with other metrics
      }

      // 5. ADMIN INTERACTIONS
      try {
        final noticesQuery = await _noticesCollection
            .where('communityId', isEqualTo: communityId)
            .where('createdAt', isGreaterThan: lastMonth)
            .get();

        int totalAdminInteractions = 0;
        int recentDayAdmin = 0;
        int recentWeekAdmin = 0;
        int recentMonthAdmin = 0;

        for (var doc in noticesQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (await _isUserAdmin(data['userId'] as String)) {
            totalAdminInteractions++;

            final createdAt = (data['createdAt'] as Timestamp).toDate();
            if (createdAt.isAfter(lastDay)) recentDayAdmin++;
            if (createdAt.isAfter(lastWeek)) recentWeekAdmin++;
            if (createdAt.isAfter(lastMonth)) recentMonthAdmin++;
          }
        }

        engagementComponents['adminInteractions'] = totalAdminInteractions;
        recentActivity['lastDay'] =
            (recentActivity['lastDay'] ?? 0) + recentDayAdmin;
        recentActivity['lastWeek'] =
            (recentActivity['lastWeek'] ?? 0) + recentWeekAdmin;
        recentActivity['lastMonth'] =
            (recentActivity['lastMonth'] ?? 0) + recentMonthAdmin;
      } catch (e) {
        // Continue with other metrics
      }

      // Calculate weighted engagement score
      double weightedScore = 0;
      int nonZeroComponents = 0;

      engagementWeights.forEach((component, weight) {
        final value = engagementComponents[component] ?? 0;
        weightedScore += (value * weight);
        if (value > 0) nonZeroComponents++;
      });

      // Adjust score based on component coverage
      double componentCoverage = nonZeroComponents / engagementWeights.length;
      weightedScore *= componentCoverage;

      // Calculate recency bonus (more recent activity increases engagement)
      double recencyMultiplier = 1.0;
      if (recentActivity['lastDay']! > 0) recencyMultiplier += 0.2;
      if (recentActivity['lastWeek']! > recentActivity['lastDay']! * 3)
        recencyMultiplier += 0.15;
      if (recentActivity['lastMonth']! > recentActivity['lastWeek']! * 2)
        recencyMultiplier += 0.1;

      // Cap the recency multiplier
      recencyMultiplier = recencyMultiplier.clamp(1.0, 1.5);

      // Calculate base engagement rate with component coverage factor
      int baseEngagementRate =
          ((weightedScore / (membersCount > 0 ? membersCount : 1)) * 100)
              .round();

      // Apply recency multiplier
      int finalEngagementRate =
          (baseEngagementRate * recencyMultiplier).round();

      // Normalize the engagement rate
      finalEngagementRate = finalEngagementRate.clamp(0, 100);

      // Apply minimum engagement rate for active communities, but consider component coverage
      if (finalEngagementRate < 15 && recentActivity['lastWeek']! > 0) {
        finalEngagementRate = (15 * componentCoverage).round();
      }

      return {
        'engagementRate': finalEngagementRate,
        'engagementComponents': engagementComponents,
        'activeUsers': recentActivity['lastWeek'],
        'totalMembers': membersCount,
        'totalActivities': weightedScore.round(),
        'recentActivity': recentActivity,
      };
    } catch (e) {
      // Return default values
      return {
        'engagementRate': 40,
        'engagementComponents': {
          'userLikesComments': 0,
          'volunteerParticipation': 0,
          'marketplaceActivity': 0,
          'reportSubmissions': 0,
          'chatActivity': 0,
          'adminInteractions': 0,
        },
        'activeUsers': 1,
        'totalMembers': 4,
        'totalActivities': 0,
        'recentActivity': {
          'lastDay': 0,
          'lastWeek': 0,
          'lastMonth': 0,
        },
      };
    }
  }
}
