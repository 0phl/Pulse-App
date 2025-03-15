import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference get _auditLogsCollection => 
      _firestore.collection('audit_logs');
  CollectionReference get _usersCollection =>
      _firestore.collection('users');

  // Create a new audit log entry
  Future<void> logAction({
    required String actionType,
    required String targetResource,
    required Map<String, dynamic> details,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Get user's data from Firestore
    final userDoc = await _usersCollection.doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = userDoc.data() as Map<String, dynamic>;
    final isAdmin = userData['role'] == 'admin';
    final communityId = userData['communityId'] as String;

    await _auditLogsCollection.add({
      'userId': user.uid,
      'userEmail': user.email,
      'isAdmin': isAdmin,
      'communityId': communityId,
      'actionType': actionType,
      'targetResource': targetResource,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get audit logs with pagination
  Future<QuerySnapshot> getAuditLogs({
    DocumentSnapshot? startAfter,
    int limit = 20,
    String? actionType,
    String? adminId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentAdmin = _auth.currentUser;
    if (currentAdmin == null) throw Exception('No admin logged in');

    // Get admin's community ID
    final adminDoc = await _usersCollection.doc(currentAdmin.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');
    
    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Start with base query for admin's community
    Query query = _auditLogsCollection
        .where('communityId', isEqualTo: communityId)
        .orderBy('timestamp', descending: true);

    // Apply filters if provided
    if (actionType != null) {
      query = query.where('actionType', isEqualTo: actionType);
    }
    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }
    if (startDate != null) {
      query = query.where('timestamp', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('timestamp', 
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    // Apply pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    return query.limit(limit).get();
  }

  // Get audit log by ID
  Future<DocumentSnapshot?> getAuditLog(String logId) async {
    return _auditLogsCollection.doc(logId).get();
  }

  // Get audit logs for a specific resource
  Stream<QuerySnapshot> getAuditLogsForResource(String resourceId) {
    return _auditLogsCollection
        .where('targetResource', isEqualTo: resourceId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get audit logs for specific action types
  Stream<QuerySnapshot> getAuditLogsByActionTypes(List<String> actionTypes) {
    return _auditLogsCollection
        .where('actionType', whereIn: actionTypes)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Delete old audit logs (retention policy)
  Future<void> deleteOldAuditLogs(int retentionDays) async {
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: retentionDays));
    
    final snapshot = await _auditLogsCollection
        .where('timestamp', 
            isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  // Export audit logs
  Future<List<Map<String, dynamic>>> exportAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? actionType,
  }) async {
    // Get admin's community ID first
    final currentAdmin = _auth.currentUser;
    if (currentAdmin == null) throw Exception('No admin logged in');

    final adminDoc = await _usersCollection.doc(currentAdmin.uid).get();
    if (!adminDoc.exists) throw Exception('Admin not found');
    
    final adminData = adminDoc.data() as Map<String, dynamic>;
    final communityId = adminData['communityId'] as String;

    // Start with community-specific query
    Query query = _auditLogsCollection
        .where('communityId', isEqualTo: communityId)
        .orderBy('timestamp', descending: true);

    if (startDate != null) {
      query = query.where('timestamp', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('timestamp', 
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (actionType != null) {
      query = query.where('actionType', isEqualTo: actionType);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}

// Enum for common action types
enum AuditActionType {
  // User related
  userViewed('USER_VIEWED'),
  userStatsViewed('USER_STATS_VIEWED'),

  // Reports
  reportViewed('REPORT_VIEWED'),
  reportHandled('REPORT_HANDLED'),

  // Notices
  noticeViewed('NOTICE_VIEWED'),
  noticeCreated('NOTICE_CREATED'),
  noticeUpdated('NOTICE_UPDATED'),
  noticeDeleted('NOTICE_DELETED'),

  // Marketplace
  marketplaceViewed('MARKETPLACE_VIEWED'),
  marketplaceItemViewed('MARKETPLACE_ITEM_VIEWED'),
  marketplaceItemRemoved('MARKETPLACE_ITEM_REMOVED'),
  sellerWarned('SELLER_WARNED'),

  // Volunteer Posts - Admin Actions
  volunteerPostsViewed('VOLUNTEER_POSTS_VIEWED'),
  volunteerPostViewed('VOLUNTEER_POST_VIEWED'),
  volunteerPostRemoved('VOLUNTEER_POST_REMOVED'),

  // Volunteer Posts - User Actions
  volunteerSignedUp('VOLUNTEER_SIGNED_UP'),
  volunteerCancelled('VOLUNTEER_CANCELLED'),

  // Security
  loginAttempt('LOGIN_ATTEMPT'),
  passwordChanged('PASSWORD_CHANGED'),
  settingsChanged('SETTINGS_CHANGED'),
  dataExported('DATA_EXPORTED');

  final String value;
  const AuditActionType(this.value);

  @override
  String toString() => value;
}
