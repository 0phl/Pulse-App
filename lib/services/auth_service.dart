import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/admin_user.dart';
import '../models/firestore_user.dart';
import 'user_session_service.dart';
import 'community_notice_service.dart';
import 'notification_service.dart';
import 'user_activity_service.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final UserSessionService _sessionService = UserSessionService();
  final CommunityNoticeService _noticeService = CommunityNoticeService();
  final UserActivityService _activityService = UserActivityService();
  final _maxRetries = 3;
  final _retryDelay = const Duration(milliseconds: 500);

  // Get current user
  User? get currentUser => _auth.currentUser;

  Future<void> _waitForConnection() async {
    final connectedRef = FirebaseDatabase.instance.ref(".info/connected");
    bool isConnected = false;
    try {
      final snapshot = await connectedRef.get();
      isConnected = snapshot.value as bool? ?? false;
      if (!isConnected) {
        await Future.delayed(_retryDelay);
      }
    } catch (e) {
      await Future.delayed(_retryDelay);
    }
  }

  Future<DataSnapshot> _queryUsernameWithRetry(
      String username, int retryCount) async {
    try {
      await _waitForConnection();
      return await _database
          .child('users')
          .orderByChild('username')
          .equalTo(username)
          .once()
          .then((event) => event.snapshot);
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(_retryDelay);
        return _queryUsernameWithRetry(username, retryCount + 1);
      }
      throw Exception('Failed to query username after $_maxRetries attempts');
    }
  }

  // Check user type and handle admin first login
  Future<Map<String, dynamic>> signInWithEmailOrUsername(
      String emailOrUsername, String password) async {
    try {
      UserCredential? userCredential;
      // First, check if input is an email
      if (emailOrUsername.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: emailOrUsername,
          password: password,
        );
      } else {
        // If not email, search for user by username
        final snapshot = await _queryUsernameWithRetry(emailOrUsername, 0);

        if (snapshot.value != null) {
          final userData = (snapshot.value as Map).values.first as Map;
          final email = userData['email'] as String;

          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No user found with this username or email.',
          );
        }
      }

      // Check if user is an admin
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Check for deactivated admin accounts first
        if ((userData['role'] == 'admin' ||
                userData['role'] == 'super_admin') &&
            userData['status'] == 'inactive') {
          // Return special object indicating deactivated account
          return {
            'userCredential': userCredential,
            'userType': 'deactivated_admin',
            'deactivationReason': userData['deactivationReason'],
            'deactivatedAt': userData['deactivatedAt'],
          };
        }

        if (userData['role'] == 'admin' || userData['role'] == 'super_admin') {
          final isFirstLogin = userData['isFirstLogin'] ?? false;

          // Save admin session data
          await _sessionService.saveUserSession(
            userId: userCredential.user!.uid,
            email: userCredential.user!.email!,
            userType: 'admin',
          );

          // Reset FCM token after login to ensure notifications work for admin
          try {
            final notificationService = NotificationService();
            await notificationService.resetTokenAfterLogin();
            debugPrint('FCM token reset after login for admin user');
          } catch (e) {
            debugPrint('Error resetting FCM token after admin login: $e');
          }

          // Track admin login activity
          await _activityService.onUserLogin();

          return {
            'userCredential': userCredential,
            'userType': 'admin',
            'requiresPasswordChange': isFirstLogin,
          };
        }
      } else {}

      // Regular user login
      // Save user session data
      await _sessionService.saveUserSession(
        userId: userCredential.user!.uid,
        email: userCredential.user!.email!,
        userType: 'user',
      );

      // Reset FCM token after login to ensure notifications work
      try {
        final notificationService = NotificationService();
        await notificationService.resetTokenAfterLogin();
        debugPrint('FCM token reset after login for regular user');
      } catch (e) {
        debugPrint('Error resetting FCM token after login: $e');
      }

      // Track user login activity
      await _activityService.onUserLogin();

      return {
        'userCredential': userCredential,
        'userType': 'user',
        'requiresPasswordChange': false,
      };
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    required String mobile,
    required DateTime birthDate,
    required String address,
    required Map<String, String> location,
    required String communityId,
    String? profileImageUrl,
    required String registrationId,
    required String verificationStatus,
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

      // Parse birthDate string to DateTime
      final birthDateTime = DateFormat('MM/dd/yyyy')
          .parse(DateFormat('MM/dd/yyyy').format(birthDate));

      // Compute full name for backward compatibility
      final fullName = middleName != null && middleName.isNotEmpty
          ? '$firstName $middleName $lastName'
          : '$firstName $lastName';

      // Save user data to Realtime Database
      await _database.child('users').child(userCredential.user!.uid).set({
        'firstName': firstName,
        if (middleName != null && middleName.isNotEmpty)
          'middleName': middleName,
        'lastName': lastName,
        'fullName': fullName, // Store combined name for backward compatibility
        'username': username,
        'email': email,
        'mobile': mobile,
        'birthDate': DateFormat('MM/dd/yyyy')
            .format(birthDate), // Keep string format for RTDB
        'address': address,
        'location': location,
        'communityId': communityId,
        'role': 'member',
        'createdAt': ServerValue.timestamp,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        'registrationId': registrationId,
        // Removed verificationStatus from RTDB since we're using Firestore for verification
      });

      // Create matching Firestore user document
      final firestoreUser = FirestoreUser(
        uid: userCredential.user!.uid,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        username: username,
        email: email,
        mobile: mobile,
        birthDate: birthDateTime,
        address: address,
        location: location,
        communityId: communityId,
        role: 'member',
        createdAt: DateTime.now(),
        profileImageUrl: profileImageUrl,
        registrationId: registrationId,
        verificationStatus: verificationStatus,
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(firestoreUser.toMap());

      // Initialize user activity tracking
      await _activityService.initializeUserActivity(userCredential.user!.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Track user activity before signing out
      await _activityService.onUserLogout();

      // First remove FCM tokens to prevent push notifications after logout
      final notificationService = NotificationService();
      await notificationService.removeUserTokens();

      // Then sign out and clear session
      await _auth.signOut();
      await _sessionService.clearUserSession();
    } catch (e) {
      debugPrint('Error during sign out: $e');
      // Still attempt to sign out even if token removal fails
      await _auth.signOut();
      await _sessionService.clearUserSession();
    }
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

  // Update user profile image
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    try {
      // Update in Realtime Database
      await _database.child('users').child(uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': ServerValue.timestamp,
      });

      // Update in Firestore
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get the user's full name to update comments
      final userSnapshot = await _database.child('users').child(uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final String fullName = userData['fullName'] as String? ?? '';

        if (fullName.isNotEmpty) {
          // Update all comments by this user with the new profile image
          await _noticeService.updateUserCommentsInfo(uid, fullName, imageUrl);
        }
      }
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
  }

  // Update user profile data
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      // Prepare data for Realtime Database
      final rtdbData = Map<String, dynamic>.from(data);
      rtdbData['updatedAt'] = ServerValue.timestamp;

      // Update in Realtime Database
      await _database.child('users').child(uid).update(rtdbData);

      // Prepare data for Firestore
      final firestoreData = Map<String, dynamic>.from(data);
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();

      // Update in Firestore
      await _firestore.collection('users').doc(uid).update(firestoreData);

      // If name or profile image was updated, update all comments by this user
      if (data.containsKey('fullName') || data.containsKey('profileImageUrl')) {
        final String? fullName = data['fullName'] as String?;
        final String? profileImageUrl = data['profileImageUrl'] as String?;

        if (fullName != null) {
          // Update all comments by this user with the new name and profile image
          await _noticeService.updateUserCommentsInfo(
              uid, fullName, profileImageUrl);
        }
      }
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }
}
