import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geniuspay_flutter/geniuspay_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/config/app_constants.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_prefs_cache.dart';
import 'core/offline/ticket_cache.dart';
import 'core/offline/manifest_cache.dart';
import 'core/offline/favorites_cache.dart';
import 'core/settings/settings_cache.dart';
import 'core/push/push_service.dart';
import 'firebase_options.dart';
import 'app.dart';

/// Handler exécuté dans un isolate séparé quand l'app est fermée (terminated).
/// Doit être une fonction top-level (pas une méthode de classe).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être initialisé avant tout traitement dans l'isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM Background] ${message.notification?.title}');
  // OneSignal gère l'affichage automatiquement — pas besoin d'afficher manuellement ici
}

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await initializeDateFormatting('fr_FR', null);
  await TicketCache.init();
  await ManifestCache.init();
  await FavoritesCache.init();
  await SettingsCache.init();
  await NotifPrefsCache.init();

  // 1. Firebase — doit être initialisé en premier
  await _initFirebase();

  // 2. Handler background FCM (app fermée)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. OneSignal — initialisé après Firebase
  await PushService.init();

  // 4. Local notifications — canaux + gestion du tap
  tz.initializeTimeZones();
  await LocalNotificationService.init();
  await LocalNotificationService.handleLaunchDetails();

  // 5. GeniusPay — SDK de paiement natif
  GeniusPay.initialize(GeniusPayConfig(
    apiKey:    kGeniusPayApiKey,
    apiSecret: kGeniusPayApiSecret,
    sandbox:   kGeniusPaySandbox,
    baseUrl:   'https://pay.genius.ci/api/v1/merchant/payments',
  ));

  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: TransProApp()));
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Stub placeholder — lance `flutterfire configure` pour générer
    // lib/firebase_options.dart avec les vraies valeurs du projet Firebase
    debugPrint('[Firebase] Initialisation ignorée: $e');
  }
}
