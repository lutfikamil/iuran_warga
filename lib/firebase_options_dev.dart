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
    authDomain: 'mulialand-dev.firebaseapp.com',
    projectId: 'mulialand-dev',
    storageBucket: 'mulialand-dev.firebasestorage.app',
    messagingSenderId: '764452059903',
    appId: '1:764452059903:web:e34b95086f4af777e36aca',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdlZceQ1JgC779PbEeqwev7mxhqJ192GQ',
    appId: '1:308053015689:android:85e2f3f1e9e3dbc3285a58',
    messagingSenderId: '308053015689',
    projectId: 'mulialand',
    storageBucket: 'mulialand.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIj75hC3hKrUz3mdwBiFLKkZiy1FfZe20',
    appId: '1:308053015689:web:7cf9d96863bb7dec285a58',
    messagingSenderId: '308053015689',
    projectId: 'mulialand',
    authDomain: 'mulialand.firebaseapp.com',
    storageBucket: 'mulialand.firebasestorage.app',
  );
}
