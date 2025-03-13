import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/admin_user.dart';
import '../models/community.dart';
import '../services/community_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _communityService = CommunityService();

  // Get users from RTDB for admin's community
  Future<List<Map<String, dynamic>>> getRTDBUsers() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final adminDoc = await _usersCollection.doc(user.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Get all users from RTDB
    final usersSnapshot = await _database.child('users').get();
    if (!usersSnapshot.exists) return [];

    final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
    List<Map<String, dynamic>> communityUsers = [];

    usersData.forEach((key, value) {
      if (value is Map && 
          value['communityId'] == communityId && 
          value['role'] == 'member') {
        communityUsers.add({
          'uid': key,
          'fullName': value['fullName'] ?? '',
          'email': value['email'] ?? '',
          'mobile': value['mobile'] ?? '',
          'address': value['address'] ?? '',
          'barangay': value['location']?['barangay'] ?? '',
          'createdAt': DateTime.fromMillisecondsSinceEpoch(value['createdAt'] ?? 0),
        });
      }
    });

    // Sort by newest first
    communityUsers.sort((a, b) => (b['createdAt'] as DateTime)
        .compareTo(a['createdAt'] as DateTime));

    return communityUsers;
  }

  // Collection references
  CollectionReference get _usersCollection => 
      _firestore.collection('users');
  CollectionReference get _communitiesCollection =>
      _firestore.collection('communities');
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
  CollectionReference get _chatsCollection =>
      _firestore.collection('chats');

  // Get current admin's community
  Future<Community?> getCurrentAdminCommunity() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final adminDoc = await _usersCollection.doc(user.uid).get();
    if (!adminDoc.exists) return null;

    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    return _communityService.getCommunity(communityId);
  }

  // Get user statistics from RTDB
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

    // Get all users from RTDB
    final usersSnapshot = await _database.child('users').get();
    if (!usersSnapshot.exists) return {'totalUsers': 0, 'communityUsers': 0, 'newUsersThisWeek': 0};

    final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));

    int totalUsers = 0;
    int communityUsers = 0;
    int newUsersThisWeek = 0;

    usersData.forEach((key, value) {
      if (value is Map && value['role'] == 'member') {
        totalUsers++;
      }
      if (value is Map && value['communityId'] == communityId && value['role'] != 'admin' && value['role'] != 'super_admin') {
        communityUsers++;

        // Count new users in the last 7 days
        final createdAt = DateTime.fromMillisecondsSinceEpoch(value['createdAt'] ?? 0);
        if (createdAt.isAfter(lastWeek)) {
          newUsersThisWeek++;
        }
      }
    });

    return {
      'totalUsers': totalUsers,
      'communityUsers': communityUsers,
      'newUsersThisWeek': newUsersThisWeek,
    };
  }

  // Get community statistics
  Future<Map<String, dynamic>> getCommunityStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }
    
    final communitiesQuery = await _communitiesCollection.get();
    
    int totalCommunities = 0;
    int activeCommunities = 0;

    for (var doc in communitiesQuery.docs) {
      totalCommunities++;
      final communityData = doc.data() as Map<String, dynamic>;
      if (communityData['status'] == 'active') {
        activeCommunities++;
      }
    }

    return {
      'totalCommunities': totalCommunities,
      'activeCommunities': activeCommunities,
      'inactiveCommunities': totalCommunities - activeCommunities,
    };
  }

  // Get activity statistics
  Future<Map<String, dynamic>> getActivityStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }
    
    final reportsCount = (await _reportsCollection.count().get()).count;
    final volunteerPostsCount = (await _volunteerPostsCollection.count().get()).count;
    
    // Get recent audit logs (last 24 hours)
    final yesterday = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    final recentLogsCount = (await _auditLogsCollection
      .where('timestamp', isGreaterThan: yesterday)
      .count()
      .get()).count;

    // Get active chats (with messages in last 7 days)
    final lastWeek = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final activeChatsCount = (await _chatsCollection
      .where('lastMessageAt', isGreaterThan: lastWeek)
      .count()
      .get()).count;

    return {
      'totalReports': reportsCount,
      'volunteerPosts': volunteerPostsCount,
      'recentLogs': recentLogsCount,
      'activeChats': activeChatsCount,
    };
  }

  // Get content statistics
  Future<Map<String, dynamic>> getContentStats() async {
    // Verify admin access first
    if (!await isCurrentUserAdmin()) {
      throw Exception('Permission denied: Only admins can access statistics');
    }
    
    final marketItemsCount = (await _marketItemsCollection.count().get()).count;
    final noticesCount = (await _noticesCollection.count().get()).count;
    
    // Get recent posts (last 7 days)
    final lastWeek = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final recentPostsCount = (await _volunteerPostsCollection
      .where('createdAt', isGreaterThan: lastWeek)
      .count()
      .get()).count;

    return {
      'marketItems': marketItemsCount,
      'communityNotices': noticesCount,
      'recentPosts': recentPostsCount,
    };
  }

  // Get admin user data
  Stream<AdminUser?> getAdminUser(String uid) {
    return _usersCollection
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          
          final userData = snapshot.data() as Map<String, dynamic>;
          final role = userData['role'] as String;
          
          if (role == 'admin' || role == 'super_admin') {
            // Add uid to the map since it's not stored in the document
            final userDataWithId = {
              ...userData,
              'uid': snapshot.id,
            };
            print('AdminService: User data: $userDataWithId');
            return AdminUser.fromMap(userDataWithId);
          }
          
          return null;
        });
  }

  // Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _usersCollection.doc(user.uid).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data() as Map<String, dynamic>;
    return userData['role'] == 'admin' || userData['role'] == 'super_admin';
  }

  // Create new admin (only for super admin use)
  Future<void> createAdmin({
    required String email,
    required String password,
    required String fullName,
    required String communityId,
  }) async {
    // Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create admin document in users collection
    final adminUser = AdminUser(
      uid: userCredential.user!.uid,
      fullName: fullName,
      email: email,
      communityId: communityId,
      isFirstLogin: true,
      createdAt: DateTime.now(),
      status: 'active',
    );

    await _usersCollection
        .doc(userCredential.user!.uid)
        .set(adminUser.toMap());
  }

  // Update admin's first login status and handle password change
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
      
      // Update password
      await user.updatePassword(newPassword);

      // Update first login status in Firestore
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

  // Update admin status (active/inactive)
  Future<void> updateAdminStatus(String adminId, String status) async {
    await _usersCollection.doc(adminId).update({
      'status': status,
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete admin
  Future<void> deleteAdmin(String adminId) async {
    await _usersCollection.doc(adminId).delete();
    
    // Note: The associated Firebase Auth user should be deleted by the super admin
    // through the Firebase Console or a separate super admin function
  }
}
