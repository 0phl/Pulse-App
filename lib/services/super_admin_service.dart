import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_application.dart';
import '../models/community.dart';
import 'email_service.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session_service.dart';

class SuperAdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final EmailService _emailService = EmailService();
  final UserSessionService _sessionService = UserSessionService();

  // Check if current user is super admin
  Future<bool> isSuperAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['role'] == 'super_admin' &&
          userData['status'] == 'active';
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

    return _database
        .child('admin_applications')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      return data.entries
          .map((e) => AdminApplication.fromJson(
              Map<String, dynamic>.from(e.value), e.key))
          .toList()
        ..sort((a, b) =>
            b.createdAt.compareTo(a.createdAt)); // Sort in descending order
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

      // First fix: Direct reference to the community node
      final communityRef = _database.child('communities').child(communityId);

      try {
        print('Updating community status...');

        // Second fix: Use a single update operation with all fields at once
        Map<String, dynamic> updates = {
          'status': 'active',
          'adminId': userCredential.user!.uid,
          'adminName': application.fullName,
          // Use a timestamp from Dart instead of ServerValue
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };

        // Get community data for creating locationStatusId
        final communitySnapshot = await communityRef.get();
        if (!communitySnapshot.exists) throw Exception('Community not found');

        final communityData = communitySnapshot.value as Map<dynamic, dynamic>;
        final locationStatusId = Community.createLocationStatusId(
            communityData['regionCode'] as String,
            communityData['provinceCode'] as String,
            communityData['municipalityCode'] as String,
            communityData['barangayCode'] as String,
            'active');

        updates['locationStatusId'] = locationStatusId;

        // Third fix: Await the update operation and add error handling
        await communityRef.update(updates).timeout(
              const Duration(seconds: 10),
              onTimeout: () =>
                  throw TimeoutException('Community update timed out'),
            );

        // Add a small delay to ensure Firebase has processed the update
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the update
        final verifySnapshot = await communityRef.get();
        if (!verifySnapshot.exists) {
          throw Exception('Community no longer exists after update');
        }

        final verifiedData =
            Map<String, dynamic>.from(verifySnapshot.value as Map);
        print('New community status: ${verifiedData['status']}');

        if (verifiedData['status'] != 'active') {
          print(
              'Status verification failed. Current status: ${verifiedData['status']}');
          throw Exception('Community status was not updated correctly');
        }

        print('Community status updated successfully to active');
      } catch (e) {
        print('Error updating community: $e');
        // Try again with a different approach if the first attempt failed
        try {
          print('Trying alternative update method...');
          // Fourth fix: Try direct set operation for fields
          final communitySnapshot = await communityRef.get();
          if (communitySnapshot.exists) {
            final communityData =
                communitySnapshot.value as Map<dynamic, dynamic>;
            final locationStatusId = Community.createLocationStatusId(
                communityData['regionCode'] as String,
                communityData['provinceCode'] as String,
                communityData['municipalityCode'] as String,
                communityData['barangayCode'] as String,
                'active');
            await communityRef.child('status').set('active');
            await communityRef.child('adminId').set(userCredential.user!.uid);
            await communityRef.child('adminName').set(application.fullName);
            await communityRef
                .child('updatedAt')
                .set(DateTime.now().millisecondsSinceEpoch);
            await communityRef.child('locationStatusId').set(locationStatusId);
          }

          print('Alternative update method completed');
        } catch (retryError) {
          print('Alternative update method also failed: $retryError');
          // Continue with user creation even if community update fails
        }
      }

      print('Updating user role and community...');

      // Create admin user record
      final firestoreData = {
        'fullName': application.fullName,
        'email': application.email,
        'role': 'admin',
        'communityId': communityId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'isFirstLogin': true, // Add this for admin first login check
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
    print('=== ADMIN REJECTION PROCESS START ===');
    print('Application ID: $applicationId');
    print('Email: $email');
    print('Reason: $reason');

    try {
      // First verify authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      // Get the application details first to get communityId
      final applicationSnapshot = await _database
          .child('admin_applications')
          .child(applicationId)
          .get();
      if (!applicationSnapshot.exists) throw 'Application not found';

      final applicationData =
          Map<String, dynamic>.from(applicationSnapshot.value as Map);
      final communityId = applicationData['communityId'] as String?;

      print('Updating application status...');
      // Update application status first
      await _database.child('admin_applications').child(applicationId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': ServerValue.timestamp,
        'rejectedBy': currentUser.uid,
      });
      print('Application status updated successfully');

      // Send rejection email
      print('Sending rejection notification...');
      await _emailService.sendRejectionNotification(email, reason);
      print('Rejection notification sent successfully');

      // If there's an associated community, update its status too
      if (communityId != null && communityId.isNotEmpty) {
        print('Updating community status...');

        // Get community data for creating locationStatusId
        final communityRef = _database.child('communities').child(communityId);
        final communitySnapshot = await communityRef.get();
        if (communitySnapshot.exists) {
          final communityData =
              communitySnapshot.value as Map<dynamic, dynamic>;
          final locationStatusId = Community.createLocationStatusId(
              communityData['regionCode'] as String,
              communityData['provinceCode'] as String,
              communityData['municipalityCode'] as String,
              communityData['barangayCode'] as String,
              'rejected');

          await communityRef.update({
            'status': 'rejected',
            'locationStatusId': locationStatusId,
            'updatedAt': ServerValue.timestamp,
          });
          print('Community status updated successfully');
        }
      }

      print('=== ADMIN REJECTION PROCESS COMPLETE ===');
    } catch (e, stackTrace) {
      print('=== ERROR IN REJECTION PROCESS ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      throw 'Failed to reject admin application: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _sessionService.clearUserSession();
  }

  // Get all communities with their status
  Stream<List<Map<String, dynamic>>> getCommunities() {
    return _database
        .child('communities')
        .orderByChild('name')
        .onValue
        .asyncMap((event) async {
      final Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return [];

      // Convert raw data to a list of maps with admin information
      final communities = data.entries
          .map((e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value),
              })
          .toList();

      // Get all pending admin applications to filter out communities with pending applications
      final pendingApplicationsSnapshot = await _database
          .child('admin_applications')
          .orderByChild('status')
          .equalTo('pending')
          .get();

      Set<String> pendingCommunityIds = {};
      if (pendingApplicationsSnapshot.exists) {
        final pendingApps =
            pendingApplicationsSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in pendingApps.entries) {
          final appData = entry.value as Map<dynamic, dynamic>;
          if (appData.containsKey('communityId') &&
              appData['communityId'] != null) {
            pendingCommunityIds.add(appData['communityId'].toString());
          }
        }
      }

      // Filter communities:
      // 1. Keep communities that have an adminId (already assigned admin)
      // 2. Remove communities that have pending applications and no admin
      final filteredCommunities = communities.where((community) {
        final hasAdmin = community['adminId'] != null &&
            community['adminId'].toString().isNotEmpty;
        final communityId = community['id'].toString();

        // If community has an admin, always show it regardless of pending status
        if (hasAdmin) return true;

        // If community has no admin AND is in pending applications, don't show it
        if (!hasAdmin && pendingCommunityIds.contains(communityId))
          return false;

        // Otherwise show it (no admin but not pending)
        return true;
      }).toList();

      // Fetch admin data for communities with adminId
      for (final community in filteredCommunities) {
        final adminId = community['adminId'];
        if (adminId != null && adminId.toString().isNotEmpty) {
          try {
            // Get admin user document from Firestore
            final userDoc =
                await _firestore.collection('users').doc(adminId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              // Add admin name if available
              community['adminName'] = userData['fullName'] ?? 'Unknown Admin';
            } else {
              print('Admin user document not found for ID: $adminId');
            }
          } catch (e) {
            print('Error fetching admin data: $e');
            // Set a default admin name if there's an error
            community['adminName'] = 'Admin (Error Loading)';
          }
        }
      }

      return filteredCommunities;
    });
  }

  // Get admin applications as a one-time snapshot (not a stream)
  Future<List<AdminApplication>> getAdminApplicationsSnapshot() async {
    try {
      final snapshot = await _database.child('admin_applications').get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      return data.entries
          .map((e) => AdminApplication.fromJson(
              Map<String, dynamic>.from(e.value), e.key))
          .toList()
        ..sort((a, b) =>
            b.createdAt.compareTo(a.createdAt)); // Sort in descending order
    } catch (e) {
      print('Error getting admin applications snapshot: $e');
      return [];
    }
  }

  // Get communities as a one-time snapshot (not a stream)
  Future<List<Map<String, dynamic>>> getCommunitiesSnapshot() async {
    try {
      final snapshot = await _database.child('communities').get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      // Convert raw data to list of maps
      final communities = data.entries
          .map((e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value),
              })
          .toList();

      // Get all pending admin applications to filter out communities with pending applications
      final pendingApplicationsSnapshot = await _database
          .child('admin_applications')
          .orderByChild('status')
          .equalTo('pending')
          .get();

      Set<String> pendingCommunityIds = {};
      if (pendingApplicationsSnapshot.exists) {
        final pendingApps =
            pendingApplicationsSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in pendingApps.entries) {
          final appData = entry.value as Map<dynamic, dynamic>;
          if (appData.containsKey('communityId') &&
              appData['communityId'] != null) {
            pendingCommunityIds.add(appData['communityId'].toString());
          }
        }
      }

      // Filter communities:
      // 1. Keep communities that have an adminId (already assigned admin)
      // 2. Remove communities that have pending applications and no admin
      final filteredCommunities = communities.where((community) {
        final hasAdmin = community['adminId'] != null &&
            community['adminId'].toString().isNotEmpty;
        final communityId = community['id'].toString();

        // If community has an admin, always show it regardless of pending status
        if (hasAdmin) return true;

        // If community has no admin AND is in pending applications, don't show it
        if (!hasAdmin && pendingCommunityIds.contains(communityId))
          return false;

        // Otherwise show it (no admin but not pending)
        return true;
      }).toList();

      // Fetch admin data for communities with adminId
      for (final community in filteredCommunities) {
        final adminId = community['adminId'];
        if (adminId != null && adminId.toString().isNotEmpty) {
          try {
            // Get admin user document from Firestore
            final userDoc =
                await _firestore.collection('users').doc(adminId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              // Add admin name if available
              community['adminName'] = userData['fullName'] ?? 'Unknown Admin';
            } else {
              print('Admin user document not found for ID: $adminId');
            }
          } catch (e) {
            print('Error fetching admin data: $e');
            // Set a default admin name if there's an error
            community['adminName'] = 'Admin (Error Loading)';
          }
        }
      }

      return filteredCommunities;
    } catch (e) {
      print('Error getting communities snapshot: $e');
      return [];
    }
  }

  // Update admin application status
  Future<void> updateApplicationStatus(
      String applicationId, String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Not authenticated';

      // First get the application to ensure it exists
      final snapshot = await _database
          .child('admin_applications')
          .child(applicationId)
          .get();
      if (!snapshot.exists) throw 'Application not found';

      // Update the status
      await _database.child('admin_applications').child(applicationId).update({
        'status': status,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': user.uid,
      });

      // If status is 'approved', call the full approval process
      if (status == 'approved') {
        final applicationData =
            Map<String, dynamic>.from(snapshot.value as Map);
        final application =
            AdminApplication.fromJson(applicationData, applicationId);
        await approveAdminApplication(application);
      }

      // If status is 'rejected', set rejection with default reason
      if (status == 'rejected') {
        final applicationData =
            Map<String, dynamic>.from(snapshot.value as Map);
        final email = applicationData['email'] as String;
        await _database
            .child('admin_applications')
            .child(applicationId)
            .update({
          'rejectionReason': 'Application rejected by super admin',
          'rejectedAt': ServerValue.timestamp,
          'rejectedBy': user.uid,
        });

        // Send rejection email
        try {
          await _emailService.sendRejectionNotification(email,
              'Your application has been reviewed and was not approved. For more information, please contact support.');
        } catch (e) {
          print('Error sending rejection email: $e');
          // Continue even if email fails
        }
      }
    } catch (e) {
      print('Error updating application status: $e');
      throw 'Failed to update application status: $e';
    }
  }

  // Update community status
  Future<void> updateCommunityStatus(String communityId, String status,
      {String? deactivationReason}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Not authenticated';

      // First get the community to ensure it exists
      final communityRef = _database.child('communities').child(communityId);
      final snapshot = await communityRef.get();
      if (!snapshot.exists) throw 'Community not found';

      final communityData = snapshot.value as Map<dynamic, dynamic>;

      // Create location status ID if possible
      String? locationStatusId;
      try {
        locationStatusId = Community.createLocationStatusId(
            communityData['regionCode'] as String,
            communityData['provinceCode'] as String,
            communityData['municipalityCode'] as String,
            communityData['barangayCode'] as String,
            status);
      } catch (e) {
        print('Error creating locationStatusId: $e');
        // Continue without locationStatusId if it fails
      }

      // Update the status
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': user.uid,
      };

      if (locationStatusId != null) {
        updates['locationStatusId'] = locationStatusId;
      }

      // Add deactivation reason if provided and status is inactive
      if (status == 'inactive' &&
          deactivationReason != null &&
          deactivationReason.isNotEmpty) {
        updates['deactivationReason'] = deactivationReason;
        updates['deactivatedAt'] = ServerValue.timestamp;
        updates['deactivatedBy'] = user.uid;
      }

      await communityRef.update(updates);

      // If deactivating, also update the admin user to indicate their account is deactivated
      if (status == 'inactive' &&
          communityData.containsKey('adminId') &&
          communityData['adminId'] != null) {
        final adminId = communityData['adminId'];

        // Update admin document in Firestore
        await _firestore.collection('users').doc(adminId).update({
          'status': 'inactive',
          'deactivationReason':
              deactivationReason ?? 'Community deactivated by super admin',
          'deactivatedAt': FieldValue.serverTimestamp(),
          'deactivatedBy': user.uid,
        });
      }

      // If activating, also update the admin user to reactivate their account if it was deactivated
      if (status == 'active' &&
          communityData.containsKey('adminId') &&
          communityData['adminId'] != null) {
        final adminId = communityData['adminId'];

        // First check if the admin account is inactive
        final adminDoc =
            await _firestore.collection('users').doc(adminId).get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data()!;
          if (adminData['status'] == 'inactive') {
            print('Reactivating admin account: $adminId');
            // Update admin document in Firestore to reactivate
            await _firestore.collection('users').doc(adminId).update({
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': user.uid,
              // Remove deactivation fields
              'deactivationReason': FieldValue.delete(),
              'deactivatedAt': FieldValue.delete(),
              'deactivatedBy': FieldValue.delete(),
            });
            print('Admin account reactivated successfully');
          }
        }
      }
    } catch (e) {
      print('Error updating community status: $e');
      throw 'Failed to update community status: $e';
    }
  }

  // Manually reset an admin account's status to active
  Future<void> resetAdminStatus(String adminId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Not authenticated';

      print('Starting admin account reset for: $adminId');

      // Check if admin exists in Firestore
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      if (!adminDoc.exists) {
        throw 'Admin account not found in Firestore';
      }

      final adminData = adminDoc.data()!;
      if (adminData['status'] != 'inactive') {
        print('Admin account is already active, no reset needed');
        return;
      }

      // Reset admin in Firestore
      await _firestore.collection('users').doc(adminId).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        // Remove deactivation fields
        'deactivationReason': FieldValue.delete(),
        'deactivatedAt': FieldValue.delete(),
        'deactivatedBy': FieldValue.delete(),
      });
      print('Admin account reset in Firestore');

      // Check and reset in RTDB if needed
      try {
        final rtdbSnapshot =
            await _database.child('users').child(adminId).get();
        if (rtdbSnapshot.exists) {
          final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;
          if (rtdbData['status'] == 'inactive') {
            await _database.child('users').child(adminId).update({
              'status': 'active',
              'updatedAt': ServerValue.timestamp,
              'updatedBy': user.uid,
            });
            print('Admin account reset in RTDB');
          }
        }
      } catch (rtdbError) {
        // Log but continue since Firestore is the primary source
        print('Error updating RTDB admin status: $rtdbError');
      }

      print('Admin account reset completed successfully');
    } catch (e) {
      print('Error resetting admin status: $e');
      throw 'Failed to reset admin account: $e';
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
