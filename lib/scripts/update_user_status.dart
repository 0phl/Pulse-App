import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

// Run this as a one-time script to update all users' verification status
Future<void> updateAllUsersStatus() async {
  await Firebase.initializeApp();
  
  // Get all users from Firestore
  final firestoreUsers = await FirebaseFirestore.instance.collection('users').get();
  
  // Get reference to RTDB
  final rtdb = FirebaseDatabase.instance.ref();
  
  print('Found ${firestoreUsers.docs.length} users in Firestore');
  
  // For each user in Firestore
  for (var user in firestoreUsers.docs) {
    final userData = user.data();
    final userId = user.id;
    final verificationStatus = userData['verificationStatus'] ?? 'pending';
    
    print('Updating user $userId with status: $verificationStatus');
    
    // Update the user in RTDB
    try {
      await rtdb.child('users/$userId').update({
        'verificationStatus': verificationStatus,
        'isActive': verificationStatus == 'verified',
      });
      print('Successfully updated user $userId');
    } catch (e) {
      print('Error updating user $userId: $e');
    }
  }
  
  print('Finished updating all users');
}

// To run this script:
// 1. Create a simple Flutter app that calls this function
// 2. Run the app once to update all users
// 3. Remove the script after use
