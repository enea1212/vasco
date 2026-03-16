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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCUscdSh0E13Tn7KynLcCzX-yrKoZiQvxU',
    appId: '1:839868664740:web:1988fffc571fd5b066cf31',
    messagingSenderId: '839868664740',
    projectId: 'vascoapp-9adec',
    authDomain: 'vascoapp-9adec.firebaseapp.com',
    storageBucket: 'vascoapp-9adec.firebasestorage.app',
    measurementId: 'G-EE1WYG4K8Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCuQjPytRYO1g_Kwm0pw8cLIf_2jsOmRUo',
    appId: '1:839868664740:android:3b5b4f6c6ab405f166cf31',
    messagingSenderId: '839868664740',
    projectId: 'vascoapp-9adec',
    storageBucket: 'vascoapp-9adec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuzMljMJpAnIIh_El4iWGM5OyOdsOtRYE',
    appId: '1:839868664740:ios:668a40f98e29da8966cf31',
    messagingSenderId: '839868664740',
    projectId: 'vascoapp-9adec',
    storageBucket: 'vascoapp-9adec.firebasestorage.app',
    iosBundleId: 'com.example.vasco',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBuzMljMJpAnIIh_El4iWGM5OyOdsOtRYE',
    appId: '1:839868664740:ios:668a40f98e29da8966cf31',
    messagingSenderId: '839868664740',
    projectId: 'vascoapp-9adec',
    storageBucket: 'vascoapp-9adec.firebasestorage.app',
    iosBundleId: 'com.example.vasco',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCUscdSh0E13Tn7KynLcCzX-yrKoZiQvxU',
    appId: '1:839868664740:web:d9cb3a764f6d089566cf31',
    messagingSenderId: '839868664740',
    projectId: 'vascoapp-9adec',
    authDomain: 'vascoapp-9adec.firebaseapp.com',
    storageBucket: 'vascoapp-9adec.firebasestorage.app',
    measurementId: 'G-VH17GQTTGN',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );
}