import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyB7NBudQ89T9KFrSYonzmvotE9N-xC-d-U',
        authDomain: 'pulse-app-ea5be.firebaseapp.com',
        databaseURL: 'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app',
        projectId: 'pulse-app-ea5be',
        storageBucket: 'pulse-app-ea5be.firebasestorage.app',
        messagingSenderId: '46357625509',
        appId: '1:46357625509:web:0f04a6754ccac99eb22b4c',
      );
    }
    
    // Your existing mobile configuration
    return const FirebaseOptions(
      apiKey: 'AIzaSyBQ9XN_Y9RcztUrRTOwZEeMuHos9Np7umk',
      appId: '1:46357625509:android:badf977e49f11ed0b22b4c',
      messagingSenderId: '46357625509',
      projectId: 'pulse-app-ea5be',
      storageBucket: 'pulse-app-ea5be.appspot.com',
    );
  }
}