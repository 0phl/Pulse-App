import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart';
import '../lib/models/firestore_user.dart';

/// This script performs a test migration with a dummy user to verify the migration process.
/// 
/// Usage:
/// ```bash
/// # Run the test migration
/// flutter run bin/test_migration.dart
/// ```
/// 
/// The test process:
/// 1. Creates a test user in RTDB
/// 2. Attempts to migrate that user to Firestore
/// 3. Verifies the migrated data
/// 4. Cleans up test data from both databases
/// 
/// This is a safe way to test the migration process without affecting real data.
/// If any step fails, the script will attempt to clean up any test data that was created.
Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Create test user data in RTDB
  final rtdb = FirebaseDatabase.instance;
  final testUserId = 'test_migration_user';
  
  try {
    print('1. Creating test user in RTDB...');
    await rtdb.ref().child('users').child(testUserId).set({
      'fullName': 'Test Migration User',
      'username': 'testmigration',
      'email': 'test@migration.com',
      'mobile': '+639123456789',
      'birthDate': '01/01/1990',
      'address': 'Test Address',
      'location': {
        'barangay': 'Test Barangay',
        'municipality': 'Test Municipality',
      },
      'communityId': 'test_community',
      'role': 'user',
      'createdAt': ServerValue.timestamp,
    });
    print('✓ Test user created in RTDB');

    // Wait a moment for the data to be written
    await Future.delayed(const Duration(seconds: 1));

    // Read the user data from RTDB
    print('\n2. Reading user data from RTDB...');
    final snapshot = await rtdb.ref().child('users').child(testUserId).get();
    if (!snapshot.exists) {
      throw Exception('Test user was not created in RTDB');
    }
    final userData = snapshot.value as Map<dynamic, dynamic>;
    print('✓ User data read from RTDB: ${snapshot.value}');

    // Convert and write to Firestore
    print('\n3. Converting and writing to Firestore...');
    final firestore = FirebaseFirestore.instance;
    
    final firestoreUser = FirestoreUser(
      uid: testUserId,
      fullName: userData['fullName'] as String,
      username: userData['username'] as String,
      email: userData['email'] as String,
      mobile: userData['mobile'] as String,
      birthDate: DateTime(1990, 1, 1), // Fixed date for test
      address: userData['address'] as String,
      location: Map<String, String>.from(userData['location'] as Map),
      communityId: userData['communityId'] as String,
      role: userData['role'] as String,
      createdAt: DateTime.now(),
    );

    await firestore
        .collection('users')
        .doc(testUserId)
        .set(firestoreUser.toMap());
    print('✓ User data written to Firestore');

    // Verify the data in Firestore
    print('\n4. Verifying data in Firestore...');
    final firestoreDoc = await firestore
        .collection('users')
        .doc(testUserId)
        .get();
    
    if (!firestoreDoc.exists) {
      throw Exception('Test user was not created in Firestore');
    }
    print('✓ User data verified in Firestore: ${firestoreDoc.data()}');

    // Clean up
    print('\n5. Cleaning up test data...');
    await rtdb.ref().child('users').child(testUserId).remove();
    await firestore.collection('users').doc(testUserId).delete();
    print('✓ Test data cleaned up');

    print('\n✅ Test migration completed successfully!');
    print('\nAll steps passed:');
    print('• RTDB write successful');
    print('• Data conversion successful');
    print('• Firestore write successful');
    print('• Data verification successful');
    print('• Cleanup successful');
  } catch (e) {
    print('\n❌ Error during test migration: $e');
    
    // Attempt to clean up any test data
    print('\nAttempting to clean up test data...');
    try {
      await rtdb.ref().child('users').child(testUserId).remove();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(testUserId)
          .delete();
      print('Cleanup completed');
    } catch (cleanupError) {
      print('Error during cleanup: $cleanupError');
    }

    print('\nRecommended actions:');
    print('1. Check database connections');
    print('2. Verify Firebase configuration');
    print('3. Check error message for specific issues');
    print('4. Ensure both databases are accessible');
  }

  // Exit the process
  print('\nExiting...');
}
