import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class SocialAuthService {
  static final _google = GoogleSignIn(scopes: ['email', 'profile']);

  /// Retourne l'access token Google, ou null si annulé.
  static Future<String?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      // Préférer accessToken (fonctionne avec /userinfo), idToken en fallback
      return auth.accessToken ?? auth.idToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    try { await _google.signOut(); } catch (_) {}
  }

  /// Retourne l'access token Facebook, ou null si annulé.
  static Future<String?> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success) return null;
      return result.accessToken?.tokenString;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOutFacebook() async {
    try { await FacebookAuth.instance.logOut(); } catch (_) {}
  }
}
