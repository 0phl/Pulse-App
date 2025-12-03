import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/community_service.dart';

// Class to represent community deactivation status
class CommunityDeactivationStatus {
  final bool isDeactivated;
  final DateTime? deactivatedAt;

  CommunityDeactivationStatus({
    required this.isDeactivated,
    this.deactivatedAt,
  });

  // Convenience constructor for active status
  CommunityDeactivationStatus.active()
      : isDeactivated = false,
        deactivatedAt = null;

  // Convenience constructor for inactive status
  CommunityDeactivationStatus.inactive({DateTime? timestamp})
      : isDeactivated = true,
        deactivatedAt = timestamp;
}

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final CommunityService _communityService = CommunityService();

  Future<CommunityDeactivationStatus> checkCommunityStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return CommunityDeactivationStatus.active();
      }

      final community = await _communityService.getUserCommunity(user.uid);
      if (community == null) {
        // If no community is found, consider it active (to avoid false positives)
        return CommunityDeactivationStatus.active();
      }

      final communityRef = _database.child('communities').child(community.id);
      final snapshot = await communityRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final status = data['status'] as String?;

        if (status == 'inactive') {
          // Community is deactivated
          final deactivatedAtTimestamp = data['updatedAt'] as int?;
          DateTime? deactivatedAt;

          if (deactivatedAtTimestamp != null) {
            deactivatedAt = DateTime.fromMillisecondsSinceEpoch(deactivatedAtTimestamp);
          }

          return CommunityDeactivationStatus.inactive(timestamp: deactivatedAt);
        }
      }

      // If we get here, community is active
      return CommunityDeactivationStatus.active();
    } catch (e) {
      debugPrint('Error checking community status: $e');
      // On error, assume community is active to prevent false positives
      return CommunityDeactivationStatus.active();
    }
  }

  // Stream that monitors community status in real-time
  Stream<CommunityDeactivationStatus> streamCommunityStatus() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield CommunityDeactivationStatus.active();
      return;
    }

    try {
      final community = await _communityService.getUserCommunity(user.uid);
      if (community == null) {
        yield CommunityDeactivationStatus.active();
        return;
      }

      // Listen to the community's status changes
      await for (final event in _database
          .child('communities')
          .child(community.id)
          .onValue) {

        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final status = data['status'] as String?;

          if (status == 'inactive') {
            // Community is deactivated
            final deactivatedAtTimestamp = data['updatedAt'] as int?;
            DateTime? deactivatedAt;

            if (deactivatedAtTimestamp != null) {
              deactivatedAt =
                  DateTime.fromMillisecondsSinceEpoch(deactivatedAtTimestamp);
            }

            yield CommunityDeactivationStatus.inactive(timestamp: deactivatedAt);
          } else {
            // Community is active
            yield CommunityDeactivationStatus.active();
          }
        } else {
          // If snapshot doesn't exist, assume community is active
          yield CommunityDeactivationStatus.active();
        }
      }
    } catch (e) {
      debugPrint('Error in streamCommunityStatus: $e');
      // On error, assume community is active to prevent false positives
      yield CommunityDeactivationStatus.active();
    }
  }

  Future<String?> getUserCommunityId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userSnapshot = await _database.child('users').child(user.uid).get();
      if (!userSnapshot.exists) return null;

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      return userData['communityId'] as String?;
    } catch (e) {
      debugPrint('Error getting user community ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      return userDoc.data();
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }
}
