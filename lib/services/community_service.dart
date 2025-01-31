import 'package:firebase_database/firebase_database.dart';
import '../models/community.dart';

class CommunityService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Fetch all communities
  Stream<List<Community>> getCommunities() {
    return _database.child('communities').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries.map((entry) {
        return Community.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
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
  Future<String> createCommunity(String name, String description) async {
    final newCommunityRef = _database.child('communities').push();
    await newCommunityRef.set({
      'name': name,
      'description': description,
      'createdAt': ServerValue.timestamp,
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
