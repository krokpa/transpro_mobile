// Généré par flutterfire configure — valeurs dans lib/core/config/app_constants.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'core/config/app_constants.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: plateforme non configurée.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:           kFirebaseAndroidApiKey,
    appId:            kFirebaseAndroidAppId,
    messagingSenderId: kFirebaseMessagingSenderId,
    projectId:        kFirebaseProjectId,
    storageBucket:    kFirebaseStorageBucket,
  );

  // Compléter kFirebaseIos* dans app_constants.dart après avoir ajouté
  // ios/Runner/GoogleService-Info.plist puis relancé : flutterfire configure
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:           kFirebaseIosApiKey,
    appId:            kFirebaseIosAppId,
    messagingSenderId: kFirebaseMessagingSenderId,
    projectId:        kFirebaseProjectId,
    storageBucket:    kFirebaseStorageBucket,
    iosClientId:      kFirebaseIosClientId,
    iosBundleId:      kFirebaseIosBundleId,
  );
}
