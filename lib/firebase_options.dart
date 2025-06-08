// ignore_for_file: combinators_ordering, no_default_cases, unnecessary_brace_in_string_interps, lines_longer_than_80_chars

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
          'Linux is not supported yet.',
        );
      default:
        throw UnsupportedError(
          'Unknown platform ${defaultTargetPlatform}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAWZBmwY834MCSI7ioedbbYwqjOyymQws8',
    appId: '1:581519950118:android:cd1031979e413730a001e7',
    messagingSenderId: '581519950118',
    projectId: 'homi-dc039',
    storageBucket: 'homi-dc039.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDa5iiEl9j7kkwbXMI21YNi6-SxMm-w3HI',
    appId: '1:581519950118:ios:649e6845631a13eaa001e7',
    messagingSenderId: '581519950118',
    projectId: 'homi-dc039',
    storageBucket: 'homi-dc039.firebasestorage.app',
    iosBundleId: 'com.example.wiseSplashScreen',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAg4P4CfaX0iAxZTnNSiZAOOztlQZvQBkI',
    appId: '1:581519950118:web:314b52895a030b7ca001e7',
    messagingSenderId: '581519950118',
    projectId: 'homi-dc039',
    authDomain: 'homi-dc039.firebaseapp.com',
    storageBucket: 'homi-dc039.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDa5iiEl9j7kkwbXMI21YNi6-SxMm-w3HI',
    appId: '1:581519950118:ios:649e6845631a13eaa001e7',
    messagingSenderId: '581519950118',
    projectId: 'homi-dc039',
    storageBucket: 'homi-dc039.firebasestorage.app',
    iosBundleId: 'com.example.wiseSplashScreen',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAg4P4CfaX0iAxZTnNSiZAOOztlQZvQBkI',
    appId: '1:581519950118:web:70219b5b4ec6815ca001e7',
    messagingSenderId: '581519950118',
    projectId: 'homi-dc039',
    authDomain: 'homi-dc039.firebaseapp.com',
    storageBucket: 'homi-dc039.firebasestorage.app',
  );

}
