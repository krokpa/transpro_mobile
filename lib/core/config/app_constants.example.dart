// ============================================================
// TransPro Mobile — Template des constantes (fichier d'exemple)
// Copier ce fichier :
//   cp lib/core/config/app_constants.example.dart \
//      lib/core/config/app_constants.dart
// Puis remplir les valeurs réelles.
// ============================================================

// ─── API ─────────────────────────────────────────────────────
// Développement : IP LAN de la machine qui fait tourner l'API
//   Windows : ipconfig → "Adresse IPv4"
//   Mac/Linux : ifconfig | grep "inet "
// Production : https://api.votre-domaine.com/api/v1
const kApiBaseUrl = 'http://192.168.X.X:3001/api/v1';
const kSocketUrl  = 'http://192.168.X.X:3001';

// URL web publique (page de récupération de billet /ticket/<ref>) — liens partagés.
const kPublicWebUrl = 'https://app.votre-domaine.com';

// ─── OneSignal (notifications push) ──────────────────────────
// 1. Créer un compte sur https://app.onesignal.com
// 2. New App → "TransPro Mobile"
// 3. Settings → Keys & IDs → App ID
const kOneSignalAppId = 'VOTRE_ONESIGNAL_APP_ID';

// ─── Mapbox (cartes) ──────────────────────────────────────────
// Option A : Laisser vide + utiliser openStreetMap (gratuit, aucune clé)
// Option B : https://account.mapbox.com → Tokens → Default public token
const kMapboxToken = 'pk.VOTRE_TOKEN_MAPBOX';
const kMapboxStyle = 'streets-v12'; // streets-v12 | satellite-streets-v12 | light-v11

// ─── Firebase — Android ───────────────────────────────────────
// 1. https://console.firebase.google.com → Nouveau projet → Ajouter une app Android
//    Package : ci.transpro.transpro_mobile
// 2. Télécharger google-services.json → android/app/
// 3. Lancer : flutterfire configure
// Les valeurs ci-dessous sont copiées depuis google-services.json
const kFirebaseAndroidApiKey     = 'AIzaSy_VOTRE_CLE_ANDROID';
const kFirebaseAndroidAppId      = '1:VOTRE_SENDER_ID:android:VOTRE_APP_HASH';
const kFirebaseMessagingSenderId = 'VOTRE_SENDER_ID';
const kFirebaseProjectId         = 'VOTRE_PROJECT_ID';
const kFirebaseStorageBucket     = 'VOTRE_PROJECT_ID.firebasestorage.app';

// ─── Firebase — iOS ───────────────────────────────────────────
// 1. Dans Firebase → Ajouter une app iOS
//    Bundle ID : ci.transpro.transpro_mobile
// 2. Télécharger GoogleService-Info.plist → ios/Runner/
// 3. Lancer : flutterfire configure
const kFirebaseIosApiKey    = 'AIzaSy_VOTRE_CLE_IOS';
const kFirebaseIosAppId     = '1:VOTRE_SENDER_ID:ios:VOTRE_APP_HASH_IOS';
const kFirebaseIosClientId  = 'VOTRE_CLIENT_ID.apps.googleusercontent.com';
const kFirebaseIosBundleId  = 'ci.transpro.transpro_mobile';
