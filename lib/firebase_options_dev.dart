import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAl42xxQxkpl6_7pQyufVnILl4otyViL8w',
    appId: '1:764452059903:web:e34b95086f4af777e36aca',
    messagingSenderId: '764452059903',
    projectId: 'mulialand-dev',
    authDomain: 'mulialand-dev.firebaseapp.com',
    storageBucket: 'mulialand-dev.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkh2oRQMRRHwqpjiQKzSiZ-Xi_2xF3a1I',
    appId: '1:764452059903:android:4070085cbda325bbe36aca',
    messagingSenderId: '764452059903',
    projectId: 'mulialand-dev',
    storageBucket: 'mulialand-dev.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAl42xxQxkpl6_7pQyufVnILl4otyViL8w',
    appId: '1:764452059903:web:5fefd927276d4a17e36aca',
    messagingSenderId: '764452059903',
    projectId: 'mulialand-dev',
    authDomain: 'mulialand-dev.firebaseapp.com',
    storageBucket: 'mulialand-dev.firebasestorage.app',
  );
}
