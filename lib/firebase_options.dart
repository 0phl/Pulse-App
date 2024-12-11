import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyBQ9XN_Y9RcztUrRTOwZEeMuHos9Np7umk',
      appId: '1:46357625509:android:badf977e49f11ed0b22b4c',
      messagingSenderId: '46357625509',
      projectId: 'pulse-app-ea5be',
      storageBucket: 'pulse-app-ea5be.appspot.com',
    );
  }
}