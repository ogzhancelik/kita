import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Configured for Kita Dev project: kita-dev-c2d29
class DefaultFirebaseOptions {
  static const String vapidKey =
      'BFhF0CG_5LkBHLe200zQ6ny1gm-3Zc1wwY0KFX5wYc9tLTEa2o48usOxH6v0Fd_YBmBGrkyo6P3_Sy6S_-vP6BI';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDln7rxXDAPEH26e281q_2fGPl_8JZxm8I',
    appId: '1:923836953119:web:685ffdc5f11e99f441db2a',
    messagingSenderId: '923836953119',
    projectId: 'kita-dev-c2d29',
    authDomain: 'kita-dev-c2d29.firebaseapp.com',
    storageBucket: 'kita-dev-c2d29.firebasestorage.app',
    measurementId: 'G-PNLWT0ZM3D',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDln7rxXDAPEH26e281q_2fGPl_8JZxm8I',
    appId: '1:923836953119:android:685ffdc5f11e99f441db2a',
    messagingSenderId: '923836953119',
    projectId: 'kita-dev-c2d29',
    storageBucket: 'kita-dev-c2d29.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDln7rxXDAPEH26e281q_2fGPl_8JZxm8I',
    appId: '1:923836953119:ios:685ffdc5f11e99f441db2a',
    messagingSenderId: '923836953119',
    projectId: 'kita-dev-c2d29',
    storageBucket: 'kita-dev-c2d29.firebasestorage.app',
    iosBundleId: 'com.example.kitaFrontend',
  );
}
