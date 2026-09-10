import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPnevHUkOGbkBe8P7KnxxiCnTavwartJQ',
    appId: '1:52103461011:android:d08249f0dba78f27cbb566',
    messagingSenderId: '52103461011',
    projectId: 'runningmate-ab0b3',
    storageBucket: 'runningmate-ab0b3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCPnevHUkOGbkBe8P7KnxxiCnTavwartJQ',
    appId: '1:52103461011:ios:d08249f0dba78f27cbb566',
    messagingSenderId: '52103461011',
    projectId: 'runningmate-ab0b3',
    storageBucket: 'runningmate-ab0b3.firebasestorage.app',
    iosBundleId: 'com.example.run1220',
  );
}
