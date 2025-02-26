import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_application.dart';
import 'email_service.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuperAdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final EmailService _emailService = EmailService();

  // Check if current user is super admin
  Future<bool> isSuperAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['role'] == 'super_admin';
    } catch (e) {
      print('Error checking super admin status: $e');
      return false;
    }
  }

  // Get all admin applications
  Stream<List<AdminApplication>> getAdminApplications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error('User not logged in');
    }

    return _database.child('admin_applications').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries
          .map((e) => AdminApplication.fromJson(
              Map<String, dynamic>.from(e.value), e.key))
          .toList();
    });
  }

  // Generate random password
  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
        12, (index) => chars[Random.secure().nextInt(chars.length)]).join();
  }

  // Approve admin application
  Future<void> approveAdminApplication(AdminApplication application) async {
    final password = _generatePassword();
    print('Generated password for admin: $password');
    UserCredential? userCredential;
    String? communityId;

    try {
      print('=== ADMIN APPROVAL PROCESS START ===');
      print('Processing application for: ${application.email}');
      print('Application ID: ${application.id}');

      // First verify authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // No need for token refresh since the rules are simplified now

      // Check if email already exists
      try {
        final methods =
            await _auth.fetchSignInMethodsForEmail(application.email);
        if (methods.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'The email address is already in use.',
          );
        }
      } catch (e) {
        if (e is FirebaseAuthException && e.code != 'user-not-found') {
          rethrow;
        }
      }

      // Create admin user account
      print('Creating admin user account...');
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: application.email,
        password: password,
      );

      // Generate a new community ID if not present
      communityId = application.communityId.isEmpty
          ? _database.child('communities').push().key!
          : application.communityId;

      print('Updating community with ID: $communityId');
      // Create or update community with admin using exact name from application
      final communityRef = _database.child('communities').child(communityId);
      await communityRef.set({
        'name': application.communityName,
        // Keep description consistent with the stored name
        'description': 'Community for ${application.communityName}',
        'adminId': userCredential.user!.uid,
        'status': 'active',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      print('Updating user role and community...');

      // Create admin user record in Firestore only
      final firestoreData = {
        'fullName': application.fullName,
        'email': application.email,
        'role': 'admin',
        'communityId': communityId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      };
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(firestoreData);

      print('Updating application status...');
      // Update application status
      await _database.child('admin_applications').child(application.id).update({
        'status': 'approved',
        'adminId': userCredential.user!.uid,
        'communityId': communityId,
        'approvedAt': ServerValue.timestamp,
      });

      print('Sending credentials via email...');
      // Send credentials via email
      try {
        print('=== EMAIL SENDING PROCESS START ===');
        print('Email details:');
        print('- Recipient: ${application.email}');
        print('- Full Name: ${application.fullName}');
        print('- Community: ${application.communityName}');
        print('- Password length: ${password.length}');

        await _emailService.sendAdminCredentials(
          application.email,
          application.fullName,
          password,
          application.communityName,
        );
        print('=== EMAIL SENDING PROCESS COMPLETE ===');
      } catch (emailError) {
        print('=== EMAIL SENDING ERROR ===');
        print('Error type: ${emailError.runtimeType}');
        print('Error message: $emailError');
        print('Stack trace: ${StackTrace.current}');
        // Don't throw here - we want to continue even if email fails
      }

      print('=== ADMIN APPROVAL PROCESS COMPLETE ===');
    } catch (e, stackTrace) {
      print('Error in approveAdminApplication: $e');
      print('Stack trace: $stackTrace');

      // Clean up if we created any resources
      if (userCredential?.user != null) {
        try {
          // Delete the user from Authentication and Firestore
          await Future.wait([
            userCredential!.user!.delete(),
            _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .delete(),
          ]);

          // Delete community if we created it
          if (communityId != null && application.communityId.isEmpty) {
            await _database.child('communities').child(communityId).remove();
          }
        } catch (cleanupError) {
          print('Error during cleanup: $cleanupError');
        }
      }

      throw e.toString();
    }
  }

  // Reject admin application
  Future<void> rejectAdminApplication(
      String applicationId, String email, String reason) async {
    await _database.child('admin_applications').child(applicationId).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });

    await _emailService.sendRejectionNotification(email, reason);
  }

  // Get all communities with their status
  Stream<List<Map<String, dynamic>>> getCommunities() {
    return _database
        .child('communities')
        .orderByChild('name')
        .onValue
        .map((event) {
      final Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return [];

      return data.entries
          .map((e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value),
              })
          .toList();
    });
  }
}
