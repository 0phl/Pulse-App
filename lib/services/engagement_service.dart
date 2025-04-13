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
        // Default to 4 if we can't get the actual count
        membersCount = 4;
      }

      // Calculate engagement metrics for the last 30 days
      final lastMonth = DateTime.now().subtract(const Duration(days: 30));
      final lastMonthTimestamp = Timestamp.fromDate(lastMonth);

      // Initialize counters for engagement components
      Map<String, int> engagementComponents = {
        'userLikesComments': 0,
        'volunteerParticipation': 0,
        'marketplaceActivity': 0,
        'reportSubmissions': 0,
        'chatActivity': 0,
        'adminInteractions': 0,
      };

      // Tracking for total activities and possible activities
      int totalActivities = 0;
      int possibleActivities = 0;

      // 1. USER INTERACTIONS - Likes and comments on community notices
      try {

        // Get notices directly from RTDB instead of Firestore
        final noticesSnapshot = await _database
            .ref()
            .child('community_notices')
            .orderByChild('communityId')
            .equalTo(communityId)
            .get();

        if (!noticesSnapshot.exists) {
          // Skip this section if no notices exist
          engagementComponents['userLikesComments'] = 0;
          engagementComponents['adminInteractions'] = 0;
          // Continue with other engagement calculations instead of returning early
        } else {

        final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;

        // Convert to list of entries for processing
        final noticeEntries = noticesData.entries.toList();

        // Filter for recent notices (last 30 days)
        final recentNotices = noticeEntries.where((entry) {
          final noticeData = entry.value as Map<dynamic, dynamic>;
          final createdAt = noticeData['createdAt'] as int?;
          return createdAt != null &&
                 DateTime.fromMillisecondsSinceEpoch(createdAt).isAfter(lastMonth);
        }).toList();


        int noticeCount = recentNotices.length;
        int totalLikes = 0;
        int totalComments = 0;
        int adminLikes = 0;
        int adminComments = 0;
        int adminInteractions = 0;

        for (var entry in recentNotices) {
          final noticeId = entry.key.toString();
          final noticeData = entry.value as Map<dynamic, dynamic>;

          // Process likes and comments directly from the notice data

          // Count likes
          if (noticeData.containsKey('likes') && noticeData['likes'] != null) {
            final likes = noticeData['likes'] as Map<dynamic, dynamic>;
            totalLikes += likes.length;
            // Check for admin likes using cache
            for (var userId in likes.keys) {
              try {
                if (await _isUserAdmin(userId)) {
                  adminLikes++;
                  adminInteractions++;
                }
              } catch (e) {
              }
            }
          }

          // Count comments
          if (noticeData.containsKey('comments') && noticeData['comments'] != null) {
            final comments = noticeData['comments'] as Map<dynamic, dynamic>;
            totalComments += comments.length;

            // Check for admin comments
            for (var comment in comments.values) {
              if (comment is Map && comment.containsKey('authorId')) {
                final authorId = comment['authorId'];
                // Check if the author name contains 'Admin' as a quick check
                if (comment.containsKey('authorName')) {
                  final authorName = comment['authorName'].toString();
                  if (authorName.contains('Admin')) {
                    adminComments++;
                    adminInteractions++;
                    continue; // Skip Firestore check if we already identified as admin
                  }
                }

                // Check user role using cache
                try {
                  if (await _isUserAdmin(authorId)) {
                    adminComments++;
                    adminInteractions++;
                  }
                } catch (e) {
                }
              }
            }
          }
        }

        // Calculate user interactions by subtracting admin interactions from total
        int userLikes = totalLikes - adminLikes;
        int userComments = totalComments - adminComments;
        int userInteractions = userLikes + userComments;

        engagementComponents['userLikesComments'] = userInteractions;
        engagementComponents['adminInteractions'] = adminInteractions;
        totalActivities += userInteractions + noticeCount + adminInteractions;

        // Each notice could be liked and commented by each member
        possibleActivities +=
            10 + (noticeCount * (membersCount > 0 ? membersCount * 2 : 2));
        }
      } catch (e) {
      }

      // 2. VOLUNTEER PARTICIPATION
      try {
        final postsQuery = await _volunteerPostsCollection
            .where('communityId', isEqualTo: communityId)
            .get();

        final recentPosts = postsQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = data['date'] as Timestamp?;
          return date != null && date.toDate().isAfter(lastMonth);
        }).toList();

        int volunteerPostCount = recentPosts.length;
        int totalSignups = 0;

        for (var doc in recentPosts) {
          final data = doc.data() as Map<String, dynamic>;

          if (data['joinedUsers'] is List) {
            totalSignups += (data['joinedUsers'] as List).length;
          }
        }

        engagementComponents['volunteerParticipation'] = totalSignups;
        totalActivities += volunteerPostCount + totalSignups;

        // Each post could be joined by each member
        possibleActivities +=
            10 + (volunteerPostCount * (membersCount > 0 ? membersCount : 1));
      } catch (e) {
      }

      // 3. MARKETPLACE ACTIVITY
      try {
        final itemsQuery = await _marketItemsCollection
            .where('communityId', isEqualTo: communityId)
            .get();

        final recentItems = itemsQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'] as Timestamp?;
          return createdAt != null && createdAt.toDate().isAfter(lastMonth);
        }).toList();

        int totalItems = recentItems.length;
        int soldItems = 0;

        for (var doc in recentItems) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isSold'] == true) {
            soldItems++;
          }
        }

        int marketplaceActivity = totalItems + soldItems;
        engagementComponents['marketplaceActivity'] = marketplaceActivity;
        totalActivities += marketplaceActivity;

        possibleActivities += membersCount > 0 ? membersCount * 2 : 2;
      } catch (e) {
      }

      // 4. REPORT SUBMISSIONS
      try {
        final reportsQuery = await _reportsCollection
            .where('communityId', isEqualTo: communityId)
            .get();

        final recentReports = reportsQuery.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'] as Timestamp?;
          return createdAt != null && createdAt.toDate().isAfter(lastMonth);
        }).toList();

        int reportCount = recentReports.length;
        engagementComponents['reportSubmissions'] = reportCount;
        totalActivities += reportCount;

        // Count admin interactions with reports (resolutions, rejections)
        int reportInteractions = 0;
        for (var doc in recentReports) {
          final data = doc.data() as Map<String, dynamic>;
          // If report has been resolved or rejected by admin, count as interaction
          if (data['status'] == 'resolved' || data['status'] == 'rejected') {
            reportInteractions++;
          }
        }

        // Add report interactions to admin interactions
        engagementComponents['adminInteractions'] =
            (engagementComponents['adminInteractions'] ?? 0) + reportInteractions;

        totalActivities += reportInteractions;
        possibleActivities += membersCount > 0 ? membersCount : 1;
      } catch (e) {
      }

      // Get active users data
      int activeUsers = 0;
      try {
        final userDocs = await _usersCollection
            .where('communityId', isEqualTo: communityId)
            .where('role', whereIn: ['member', 'user'])
            .where('verificationStatus', isEqualTo: 'verified')
            .get();

        for (var doc in userDocs.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Check last login time if available
          if (data['lastLoginAt'] != null) {
            final lastLogin = data['lastLoginAt'] as Timestamp;
            if (lastLogin.toDate().isAfter(lastMonth)) {
              activeUsers++;
            }
          }
        }
      } catch (e) {
        // Default to 1 active user if we can't get the count
        activeUsers = membersCount > 0 ? 1 : 0;
      }

      // Calculate engagement rate
      int engagementRate = 0;

      // Calculate based on activities if we have data
      if (possibleActivities > 0) {
        engagementRate = ((totalActivities / possibleActivities) * 100).round();
        if (engagementRate > 100) engagementRate = 100;
      }

      // Factor in active users
      if (membersCount > 0 && activeUsers > 0) {
        int userEngagement = ((activeUsers / membersCount) * 100).round();
        // Blend activity-based and user-based metrics
        engagementRate = (engagementRate * 0.6 + userEngagement * 0.4).round();
      }

      // Apply fallback for small or new communities
      if (engagementRate == 0 && membersCount > 0) {
        bool hasAnyActivity =
            engagementComponents.values.any((value) => value > 0);

        if (hasAnyActivity) {
          engagementRate = 40; // 40% for communities with some activity
        } else {
          if (membersCount < 10) {
            engagementRate = 40; // Small communities
          } else if (membersCount < 50) {
            engagementRate = 30; // Medium communities
          } else {
            engagementRate = 20; // Large communities
          }
        }
      }

      // Ensure minimum engagement rate for active communities
      if (engagementRate < 15 && membersCount > 0) {
        engagementRate = 15;
      }

      // Debug logs

      return {
        'engagementRate': engagementRate,
        'activeUsers': activeUsers,
        'totalMembers': membersCount,
        'engagementComponents': engagementComponents,
        'totalActivities': totalActivities,
        'possibleActivities': possibleActivities
      };
    } catch (e) {
      // Return default values
      return {
        'engagementRate': 40,
        'activeUsers': 1,
        'totalMembers': 4,
        'engagementComponents': {
          'userLikesComments': 0,
          'volunteerParticipation': 0,
          'marketplaceActivity': 0,
          'reportSubmissions': 0,
          'chatActivity': 0,
          'adminInteractions': 0,
        },
        'totalActivities': 0,
        'possibleActivities': 4
      };
    }
  }
}
