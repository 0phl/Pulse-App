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
  }) async {
    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
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
}