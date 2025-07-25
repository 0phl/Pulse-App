import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/community.dart';

class CommunityService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<bool> checkCommunityExists({
    required String regionCode,
    required String provinceCode,
    required String municipalityCode,
    required String barangayCode,
  }) async {
    final locationId = Community.createLocationStatusId(
      regionCode,
      provinceCode,
      municipalityCode,
      barangayCode,
      'active'
    );

    final snapshot = await _database
        .child('communities')
        .orderByChild('locationStatusId')
        .equalTo(locationId)
        .get();

    return snapshot.exists;
  }

  Future<Community?> getCommunityByLocation({
    required String regionCode,
    required String provinceCode,
    required String municipalityCode,
    required String barangayCode,
  }) async {
    final locationId = Community.createLocationId(
      regionCode,
      provinceCode,
      municipalityCode,
      barangayCode,
    );

    final snapshot = await _database
        .child('communities')
        .orderByChild('locationId')
        .equalTo(locationId)
        .get();

    if (!snapshot.exists) return null;

    final data = snapshot.value as Map<dynamic, dynamic>;
    final entry = data.entries.first;
    return Community.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
  }

  Stream<List<Community>> getCommunities() {
    return _database.child('communities').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((entry) {
        return Community.fromMap(
            entry.key, entry.value as Map<dynamic, dynamic>);
      }).toList();
    });
  }

  Future<Community?> getCommunity(String id) async {
    try {
      final snapshot = await _database.child('communities').child(id).get();
      if (!snapshot.exists) return null;

      final value = snapshot.value;
      if (value == null || value is! Map<dynamic, dynamic>) {
        debugPrint('Invalid community data format for id: $id');
        return null;
      }

      return Community.fromMap(
        id,
        value,
      );
    } catch (e) {
      debugPrint('Error in getCommunity: $e');
      return null;
    }
  }

  Future<String> createCommunity({
    required String name,
    required String description,
    required String regionCode,
    required String provinceCode,
    required String municipalityCode,
    required String barangayCode,
    String? adminId,
  }) async {
    final exists = await checkCommunityExists(
      regionCode: regionCode,
      provinceCode: provinceCode,
      municipalityCode: municipalityCode,
      barangayCode: barangayCode,
    );

    if (exists) {
      throw Exception('An active community is already registered for this location. Please contact the administrator');
    }

    final locationId = Community.createLocationId(
      regionCode,
      provinceCode,
      municipalityCode,
      barangayCode,
    );

    final status = 'pending';
    final locationStatusId = Community.createLocationStatusId(
      regionCode,
      provinceCode,
      municipalityCode,
      barangayCode,
      status
    );

    final newCommunityRef = _database.child('communities').push();
    await newCommunityRef.set({
      'name': name,
      'description': description,
      'adminId': null, // Will be set after admin application approval
      'status': status,
      'createdAt': ServerValue.timestamp,
      'regionCode': regionCode,
      'provinceCode': provinceCode,
      'municipalityCode': municipalityCode,
      'barangayCode': barangayCode,
      'locationId': locationId,
      'locationStatusId': locationStatusId,
    });
    return newCommunityRef.key!;
  }

  Future<void> updateUserCommunity(String userId, String communityId) async {
    await _database.child('users').child(userId).update({
      'communityId': communityId,
    });
  }

  Future<Community?> getUserCommunity(String userId) async {
    try {
      final userSnapshot = await _database.child('users').child(userId).get();
      if (!userSnapshot.exists) return null;

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      final communityId = userData['communityId'];

      if (communityId == null) return null;

      // Ensure communityId is a string
      final String communityIdStr = communityId.toString();

      return getCommunity(communityIdStr);
    } catch (e) {
      debugPrint('Error in getUserCommunity: $e');
      return null;
    }
  }
}
