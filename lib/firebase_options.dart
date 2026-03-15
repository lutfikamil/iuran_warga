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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyBIj75hC3hKrUz3mdwBiFLKkZiy1FfZe20',
    authDomain: 'mulialand.firebaseapp.com',
    projectId: 'mulialand',
    storageBucket: 'mulialand.firebasestorage.app',
    messagingSenderId: '308053015689',
    appId: '1:308053015689:web:7d00abd23f721854285a58',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIj75hC3hKrUz3mdwBiFLKkZiy1FfZe20',
    authDomain: 'mulialand.firebaseapp.com',
    projectId: 'mulialand',
    storageBucket: 'mulialand.firebasestorage.app',
    messagingSenderId: '308053015689',
    appId: '1:308053015689:android:85e2f3f1e9e3dbc3285a58',
  );
}
