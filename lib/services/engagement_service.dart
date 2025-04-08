import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EngagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

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

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _usersCollection.doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['role'] == 'admin' || userData['role'] == 'super_admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
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

        // If we can't get from community doc, try counting users
        if (membersCount == 0) {
          final usersQuery = await _usersCollection
              .where('communityId', isEqualTo: communityId)
              .where('role', whereIn: ['member', 'user'])
              .count()
              .get();
          membersCount = usersQuery.count ?? 0;
        }
      } catch (e) {
        print('Error getting member count: $e');
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
        print('DEBUG: Fetching community notices from RTDB for community: $communityId');

        // Get notices directly from RTDB instead of Firestore
        final noticesSnapshot = await _database
            .ref()
            .child('community_notices')
            .orderByChild('communityId')
            .equalTo(communityId)
            .get();

        if (!noticesSnapshot.exists) {
          print('DEBUG: No community notices found in RTDB');
          // Skip this section if no notices exist
          engagementComponents['userLikesComments'] = 0;
          engagementComponents['adminInteractions'] = 0;
          // Continue with other engagement calculations instead of returning early
        } else {

        final noticesData = noticesSnapshot.value as Map<dynamic, dynamic>;
        print('DEBUG: Found ${noticesData.length} community notices in RTDB');

        // Convert to list of entries for processing
        final noticeEntries = noticesData.entries.toList();

        // Filter for recent notices (last 30 days)
        final recentNotices = noticeEntries.where((entry) {
          final noticeData = entry.value as Map<dynamic, dynamic>;
          final createdAt = noticeData['createdAt'] as int?;
          return createdAt != null &&
                 DateTime.fromMillisecondsSinceEpoch(createdAt).isAfter(lastMonth);
        }).toList();

        print('DEBUG: Found ${recentNotices.length} recent notices in the last 30 days');

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
            print('DEBUG: Found ${likes.length} likes on notice $noticeId');

            // Check for admin likes
            for (var userId in likes.keys) {
              print('DEBUG: Checking like from user: $userId');
              try {
                final userDoc = await _usersCollection.doc(userId).get();
                if (userDoc.exists) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  print('DEBUG: User role for $userId: ${userData['role']}');
                  if (userData['role'] == 'admin' ||
                      userData['role'] == 'super_admin') {
                    print('DEBUG: Found admin like');
                    adminLikes++;
                    adminInteractions++;
                  }
                } else {
                  print('DEBUG: User doc does not exist for $userId');
                }
              } catch (e) {
                print('DEBUG: Error checking user role for likes: $e');
              }
            }
          }

          // Count comments
          if (noticeData.containsKey('comments') && noticeData['comments'] != null) {
            final comments = noticeData['comments'] as Map<dynamic, dynamic>;
            totalComments += comments.length;
            print('DEBUG: Found ${comments.length} comments on notice $noticeId');

            // Check for admin comments
            for (var comment in comments.values) {
              if (comment is Map && comment.containsKey('authorId')) {
                final authorId = comment['authorId'];
                print('DEBUG: Checking comment author: $authorId');

                // Check if the author name contains 'Admin' as a quick check
                if (comment.containsKey('authorName')) {
                  final authorName = comment['authorName'].toString();
                  if (authorName.contains('Admin')) {
                    print('DEBUG: Found admin comment by name: $authorName');
                    adminComments++;
                    adminInteractions++;
                    continue; // Skip Firestore check if we already identified as admin
                  }
                }

                // Fallback to Firestore check
                try {
                  final userDoc = await _usersCollection.doc(authorId).get();
                  if (userDoc.exists) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    print('DEBUG: User role for $authorId: ${userData['role']}');
                    if (userData['role'] == 'admin' ||
                        userData['role'] == 'super_admin') {
                      print('DEBUG: Found admin comment by role check');
                      adminComments++;
                      adminInteractions++;
                    }
                  } else {
                    print('DEBUG: User doc does not exist for $authorId');
                  }
                } catch (e) {
                  print('DEBUG: Error checking user role: $e');
                }
              }
            }
          }
        }

        // Calculate user interactions by subtracting admin interactions from total
        int userLikes = totalLikes - adminLikes;
        int userComments = totalComments - adminComments;
        int userInteractions = userLikes + userComments;

        print('DEBUG: Total likes: $totalLikes, Admin likes: $adminLikes, User likes: $userLikes');
        print('DEBUG: Total comments: $totalComments, Admin comments: $adminComments, User comments: $userComments');

        engagementComponents['userLikesComments'] = userInteractions;
        engagementComponents['adminInteractions'] = adminInteractions;
        totalActivities += userInteractions + noticeCount + adminInteractions;

        print('DEBUG: User interactions: $userInteractions, Admin interactions: $adminInteractions');

        // Each notice could be liked and commented by each member
        possibleActivities +=
            10 + (noticeCount * (membersCount > 0 ? membersCount * 2 : 2));
        }
      } catch (e) {
        print('Error calculating user interactions: $e');
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
        print('Error calculating volunteer participation: $e');
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
        print('Error calculating marketplace activity: $e');
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
        print('DEBUG: Admin report interactions: $reportInteractions');

        totalActivities += reportInteractions;
        possibleActivities += membersCount > 0 ? membersCount : 1;
      } catch (e) {
        print('Error calculating report submissions: $e');
      }

      // Get active users data
      int activeUsers = 0;
      try {
        final userDocs = await _usersCollection
            .where('communityId', isEqualTo: communityId)
            .where('role', whereIn: ['member', 'user']).get();

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
        print('Error counting active users: $e');
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
      print('DEBUG: Engagement components: $engagementComponents');
      print(
          'DEBUG: Total activities: $totalActivities, Possible activities: $possibleActivities');
      print('DEBUG: Members: $membersCount, Active users: $activeUsers');
      print('DEBUG: Calculated engagement rate: $engagementRate%');
      print('DEBUG: Admin interactions count: ${engagementComponents['adminInteractions']}');

      return {
        'engagementRate': engagementRate,
        'activeUsers': activeUsers,
        'totalMembers': membersCount,
        'engagementComponents': engagementComponents,
        'totalActivities': totalActivities,
        'possibleActivities': possibleActivities
      };
    } catch (e) {
      print('Error calculating engagement: $e');
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
