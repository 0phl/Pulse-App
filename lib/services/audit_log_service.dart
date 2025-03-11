import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference get _auditLogsCollection => 
      _firestore.collection('audit_logs');

  // Create a new audit log entry
  Future<void> logAction({
    required String actionType,
    required String targetResource,
    required Map<String, dynamic> details,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // Get admin's email from Firestore
    final adminDoc = await _firestore
        .collection('admins')
        .doc(user.uid)
        .get();

    if (!adminDoc.exists) {
      throw Exception('User is not an admin');
    }

    await _auditLogsCollection.add({
      'adminId': user.uid,
      'adminEmail': user.email,
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
    Query query = _auditLogsCollection.orderBy('timestamp', descending: true);

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
    Query query = _auditLogsCollection.orderBy('timestamp', descending: true);

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
  userCreated('USER_CREATED'),
  userUpdated('USER_UPDATED'),
  userDeleted('USER_DELETED'),
  communityCreated('COMMUNITY_CREATED'),
  communityUpdated('COMMUNITY_UPDATED'),
  communityDeleted('COMMUNITY_DELETED'),
  reportHandled('REPORT_HANDLED'),
  settingsChanged('SETTINGS_CHANGED'),
  loginAttempt('LOGIN_ATTEMPT'),
  passwordChanged('PASSWORD_CHANGED'),
  dataExported('DATA_EXPORTED');

  final String value;
  const AuditActionType(this.value);

  @override
  String toString() => value;
}
