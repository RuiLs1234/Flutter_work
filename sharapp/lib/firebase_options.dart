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
        return ios;
      case TargetPlatform.macOS:
        return macos;
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
    apiKey: 'AIzaSyB9tfuRpW9XixDwd-fL5IY2zwaKsFG-AQA',
    appId: '1:629760866531:web:6d1658c04605a4a2fd6dd6',
    messagingSenderId: '629760866531',
    projectId: 'flutterapp-33945',
    authDomain: 'flutterapp-33945.firebaseapp.com',
    storageBucket: 'flutterapp-33945.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB9tfuRpW9XixDwd-fL5IY2zwaKsFG-AQA',
    appId: '1:629760866531:android:6d1658c04605a4a2fd6dd6',
    messagingSenderId: '629760866531',
    projectId: 'flutterapp-33945',
    storageBucket: 'flutterapp-33945.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB9tfuRpW9XixDwd-fL5IY2zwaKsFG-AQA',
    appId: '1:629760866531:ios:6d1658c04605a4a2fd6dd6',
    messagingSenderId: '629760866531',
    projectId: 'flutterapp-33945',
    storageBucket: 'flutterapp-33945.firebasestorage.app',
    iosBundleId: 'com.example.sharapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB9tfuRpW9XixDwd-fL5IY2zwaKsFG-AQA',
    appId: '1:629760866531:macos:6d1658c04605a4a2fd6dd6',
    messagingSenderId: '629760866531',
    projectId: 'flutterapp-33945',
    storageBucket: 'flutterapp-33945.firebasestorage.app',
    iosBundleId: 'com.example.sharapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB9tfuRpW9XixDwd-fL5IY2zwaKsFG-AQA',
    appId: '1:629760866531:windows:6d1658c04605a4a2fd6dd6',
    messagingSenderId: '629760866531',
    projectId: 'flutterapp-33945',
  );
}