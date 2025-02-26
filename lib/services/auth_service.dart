import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  // Modified sign in method
  Future<UserCredential?> signInWithEmailOrUsername(
      String emailOrUsername, String password) async {
    try {
      // First, check if input is an email
      if (emailOrUsername.contains('@')) {
        return await _auth.signInWithEmailAndPassword(
          email: emailOrUsername,
          password: password,
        );
      }

      // If not email, search for user by username
      final snapshot = await _database
          .child('users')
          .orderByChild('username')
          .equalTo(emailOrUsername)
          .once();

      if (snapshot.snapshot.value != null) {
        final userData = (snapshot.snapshot.value as Map).values.first as Map;
        final email = userData['email'] as String;

        return await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found with this username or email.',
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String mobile,
    required DateTime birthDate,
    required String address,
    required Map<String, String> location,
    required String communityId,
  }) async {
    try {
      // Check if community is active (has approved admin)
      final isActive = await isCommunityActive(communityId);
      if (!isActive) {
        throw 'Registration is not available for this community yet. Please wait for an admin to be approved.';
      }

      // Create user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Realtime Database
      await _database.child('users').child(userCredential.user!.uid).set({
        'fullName': fullName,
        'username': username,
        'email': email,
        'mobile': mobile,
        'birthDate': DateFormat('MM/dd/yyyy').format(birthDate),
        'address': address,
        'location': location,
        'communityId': communityId,
        'role': 'member',
        'createdAt': ServerValue.timestamp,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  Future<void> updateUserCommunity(String uid, String communityId) async {
    await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(uid)
        .update({'communityId': communityId});
  }

  Future<String> getOrCreateCommunity({
    required String barangayName,
    required String municipalityName,
  }) async {
    final communityName = 'Barangay $barangayName - $municipalityName';

    try {
      final communitiesRef =
          FirebaseDatabase.instance.ref().child('communities');

      // Query existing communities
      final snapshot = await communitiesRef
          .orderByChild('name')
          .equalTo(communityName)
          .get();

      if (snapshot.exists) {
        // Return existing community ID
        final Map<dynamic, dynamic> communities =
            snapshot.value as Map<dynamic, dynamic>;
        return communities.keys.first;
      }

      // Create new community
      final newCommunityRef = communitiesRef.push();
      await newCommunityRef.set({
        'name': communityName,
        'description': 'Community for $barangayName, $municipalityName',
        'status': 'pending',
        'adminId': null, // Will be set by super admin later
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'location': {
          'barangay': barangayName,
          'municipality': municipalityName,
        }
      });

      return newCommunityRef.key!;
    } catch (e) {
      throw Exception('Error getting/creating community: $e');
    }
  }

  Future<bool> isCommunityActive(String communityId) async {
    final snapshot =
        await _database.child('communities').child(communityId).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      return data['status'] == 'active'; // Only check status
    }
    return false;
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
}
