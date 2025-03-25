import 'package:firebase_database/firebase_database.dart';
import '../models/community.dart';

class CommunityService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Check if a community exists by location
  Future<bool> checkCommunityExists({
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

    return snapshot.exists;
  }

  // Get community by location
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

  // Fetch all communities
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

  // Get a single community
  Future<Community?> getCommunity(String id) async {
    final snapshot = await _database.child('communities').child(id).get();
    if (!snapshot.exists) return null;

    return Community.fromMap(
      id,
      snapshot.value as Map<dynamic, dynamic>,
    );
  }

  // Create a new community
  Future<String> createCommunity({
    required String name,
    required String description,
    required String regionCode,
    required String provinceCode,
    required String municipalityCode,
    required String barangayCode,
    String? adminId,
  }) async {
    // Check if community already exists
    final exists = await checkCommunityExists(
      regionCode: regionCode,
      provinceCode: provinceCode,
      municipalityCode: municipalityCode,
      barangayCode: barangayCode,
    );

    if (exists) {
      throw Exception('A community is already registered for this location');
    }

    final locationId = Community.createLocationId(
      regionCode,
      provinceCode,
      municipalityCode,
      barangayCode,
    );

    final newCommunityRef = _database.child('communities').push();
    await newCommunityRef.set({
      'name': name,
      'description': description,
      'adminId': null, // Will be set after admin application approval
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'regionCode': regionCode,
      'provinceCode': provinceCode,
      'municipalityCode': municipalityCode,
      'barangayCode': barangayCode,
      'locationId': locationId,
    });
    return newCommunityRef.key!;
  }

  // Update current user's community
  Future<void> updateUserCommunity(String userId, String communityId) async {
    await _database.child('users').child(userId).update({
      'communityId': communityId,
    });
  }

  // Get user's current community
  Future<Community?> getUserCommunity(String userId) async {
    final userSnapshot = await _database.child('users').child(userId).get();
    if (!userSnapshot.exists) return null;

    final userData = userSnapshot.value as Map<dynamic, dynamic>;
    final communityId = userData['communityId'] as String?;
    if (communityId == null) return null;

    return getCommunity(communityId);
  }
}
