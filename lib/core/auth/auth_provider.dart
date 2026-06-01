import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/models.dart';
import '../api/api_client.dart';
import '../notifications/campaign_config.dart';
import '../notifications/campaign_scheduler.dart';
import '../notifications/notification_prefs_cache.dart';
import '../push/push_service.dart';

// ── Helpers biométrie publics ─────────────────────────────────────────────────

/// Retourne le type de biométrie préféré sur cet appareil, ou null si aucun.
/// Note : canCheckBiometrics ne détecte que les biométries STRONG (empreinte, iris).
/// Sur Android, le déverrouillage facial est souvent WEAK → non retourné par canCheckBiometrics
/// mais bien présent dans getAvailableBiometrics(). On utilise donc uniquement cette méthode.
Future<BiometricType?> resolveAvailableBiometric() async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return null;
    final list = await auth.getAvailableBiometrics();
    if (list.isEmpty) return null;
    if (list.contains(BiometricType.face))        return BiometricType.face;
    if (list.contains(BiometricType.fingerprint)) return BiometricType.fingerprint;
    if (list.contains(BiometricType.iris))        return BiometricType.iris;
    return list.first;
  } catch (_) {
    return null;
  }
}

/// Icône Material correspondant au type biométrique.
IconData biometricIcon(BiometricType? type) => switch (type) {
  BiometricType.face => Icons.face_rounded,
  BiometricType.iris => Icons.remove_red_eye_outlined,
  _                  => Icons.fingerprint,
};

/// Raison localisée pour la demande d'authentification.
String biometricReason(BiometricType? type) => switch (type) {
  BiometricType.face => 'Déverrouillez TransPro avec Face ID',
  BiometricType.iris => 'Déverrouillez TransPro avec votre iris',
  _                  => 'Déverrouillez TransPro avec votre empreinte digitale',
};

/// Provider Riverpod — résout le type biométrique disponible (mis en cache).
final biometricTypeProvider = FutureProvider<BiometricType?>((ref) => resolveAvailableBiometric());

class AuthState {
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final bool hasPinSet;
  final bool pinVerified;
  final bool biometricEnabled;

  const AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = true,
    this.hasPinSet = false,
    this.pinVerified = false,
    this.biometricEnabled = false,
  });

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    bool? hasPinSet,
    bool? pinVerified,
    bool? biometricEnabled,
  }) => AuthState(
    user: user ?? this.user,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    isLoading: isLoading ?? this.isLoading,
    hasPinSet: hasPinSet ?? this.hasPinSet,
    pinVerified: pinVerified ?? this.pinVerified,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );

  bool get isAuthenticated => user != null && accessToken != null;
}

class AuthNotifier extends Notifier<AuthState> {
  static const _storage = FlutterSecureStorage();

  @override
  AuthState build() {
    Future.microtask(() => loadFromStorage());
    return const AuthState(isLoading: true);
  }

  Future<void> loadFromStorage() async {
    try {
      final results = await Future.wait([
        _storage.read(key: 'access_token'),
        _storage.read(key: 'refresh_token'),
        _storage.read(key: 'user'),
        _storage.read(key: 'pin_hash'),
        _storage.read(key: 'biometric_enabled'),
      ]);
      final token    = results[0];
      final refresh  = results[1];
      final userJson = results[2];
      final pinHash  = results[3];
      final bioRaw   = results[4];

      if (token != null && userJson != null) {
        // Cross-check : biométrie activée en storage mais plus disponible sur l'appareil
        bool bioEnabled = bioRaw == '1';
        if (bioEnabled) {
          final available = await resolveAvailableBiometric();
          if (available == null) {
            bioEnabled = false;
            await _storage.write(key: 'biometric_enabled', value: '0');
          }
        }

        final user = User.fromJson(jsonDecode(userJson));
        state = AuthState(
          user: user,
          accessToken: token,
          refreshToken: refresh,
          isLoading: false,
          hasPinSet: pinHash != null,
          pinVerified: false,
          biometricEnabled: bioEnabled,
        );
        return;
      }
    } catch (_) {}
    state = const AuthState(isLoading: false);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String phoneVerificationToken,
  }) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/auth/register', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'phoneVerificationToken': phoneVerificationToken,
    });
    final data = extractData(response.data);
    final user = User.fromJson(data['user']);
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await Future.wait([
      _storage.write(key: 'access_token', value: accessToken),
      _storage.write(key: 'refresh_token', value: refreshToken),
      _storage.write(key: 'user', value: jsonEncode(user.toJson())),
    ]);

    // Link this device to the user on OneSignal
    PushService.login(user.id);

    state = AuthState(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      isLoading: false,
      hasPinSet: false,
      pinVerified: true,
      biometricEnabled: false,
    );

    _syncAndApplyCampaigns(user);
  }

  Future<void> login(String email, String password) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = extractData(response.data);
    final user = User.fromJson(data['user']);
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await Future.wait([
      _storage.write(key: 'access_token', value: accessToken),
      _storage.write(key: 'refresh_token', value: refreshToken),
      _storage.write(key: 'user', value: jsonEncode(user.toJson())),
    ]);

    final pinHash = await _storage.read(key: 'pin_hash');
    final bioEnabled = await _storage.read(key: 'biometric_enabled');

    // Link this device to the user on OneSignal
    PushService.login(user.id);

    state = AuthState(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      isLoading: false,
      hasPinSet: pinHash != null,
      pinVerified: false,
      biometricEnabled: bioEnabled == '1',
    );

    _syncAndApplyCampaigns(user);
  }

  Future<void> setupPin(String pin, {bool biometric = false}) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await Future.wait([
      _storage.write(key: 'pin_hash', value: hash),
      _storage.write(key: 'biometric_enabled', value: biometric ? '1' : '0'),
    ]);
    state = state.copyWith(hasPinSet: true, pinVerified: true, biometricEnabled: biometric);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: 'pin_hash');
    if (stored == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ok = hash == stored;
    if (ok) state = state.copyWith(pinVerified: true);
    return ok;
  }

  Future<bool> unlockBiometric() async {
    final auth = LocalAuthentication();
    try {
      final type = await resolveAvailableBiometric();
      if (type == null) return false;
      final ok = await auth.authenticate(
        localizedReason: biometricReason(type),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      if (ok) state = state.copyWith(pinVerified: true);
      return ok;
    } on PlatformException catch (e) {
      // Codes connus : NotAvailable, NotEnrolled, LockedOut, PermanentlyLockedOut, PasscodeNotSet
      debugPrint('[Biometric] PlatformException ${e.code}: ${e.message}');
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        // Désactiver automatiquement après verrouillage définitif
        await setBiometricEnabled(false);
      }
      return false;
    } catch (e) {
      debugPrint('[Biometric] Erreur inattendue: $e');
      return false;
    } finally {
      // Annule tout dialogue biométrique en cours si le widget est détruit
      auth.stopAuthentication();
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled ? '1' : '0');
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<bool> isBiometricAvailable() async {
    return (await resolveAvailableBiometric()) != null;
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final dio = ref.read(dioProvider);
    final res = await dio.patch('/users/profile', data: {
      'firstName': firstName,
      'lastName': lastName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    final updated = User.fromJson(extractData(res.data));
    await _storage.write(key: 'user', value: jsonEncode(updated.toJson()));
    state = state.copyWith(user: updated);
  }

  Future<void> updateAvatar(String base64Avatar) async {
    final dio = ref.read(dioProvider);
    await dio.patch('/users/avatar', data: {'avatar': base64Avatar});
    // Re-fetch me to get updated avatar
    final meRes = await dio.get('/auth/me');
    final updated = User.fromJson(extractData(meRes.data));
    await _storage.write(key: 'user', value: jsonEncode(updated.toJson()));
    state = state.copyWith(user: updated);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post('/users/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    final dio = ref.read(dioProvider);
    final currentRefreshToken = state.refreshToken;

    // Réinitialiser l'état immédiatement → l'UI réagit sans attendre les I/O
    state = const AuthState(isLoading: false);

    // Nettoyage en arrière-plan (fire-and-forget) — ne bloque pas le thread UI
    Future.microtask(() async {
      // Annuler toutes les campagnes planifiées avant de déconnecter
      CampaignScheduler.cancelAll().ignore();
      try {
        await dio.post('/auth/logout', data: {'refreshToken': currentRefreshToken});
      } catch (_) {}
      // OneSignal.logout() peut être lent — ne pas attendre sur le thread principal
      PushService.logout().ignore();
      await Future.wait([
        _storage.delete(key: 'access_token'),
        _storage.delete(key: 'refresh_token'),
        _storage.delete(key: 'user'),
        _storage.delete(key: 'pin_hash'),
        _storage.delete(key: 'biometric_enabled'),
      ]);
    });
  }

  // ── Sync campagnes depuis l'API puis applique la config ────────────────────

  void _syncAndApplyCampaigns(User user) {
    Future.microtask(() async {
      try {
        final dio = ref.read(dioProvider);
        final endpoint = user.tenantId != null
            ? '/notifications/campaigns/config'
            : '/notifications/campaigns/config/tenant/${user.tenantId}';
        final res = await dio.get(endpoint);
        final raw = (res.data is Map && res.data['data'] != null)
            ? res.data['data'] as Map<String, dynamic>
            : res.data as Map<String, dynamic>;
        final config = CampaignConfig.fromJson(raw);
        await NotifPrefsCache.saveConfig(user.tenantId, config);
        await CampaignScheduler.applyConfig(
          config: config,
          tenantId: user.tenantId,
        );
      } catch (_) {
        // Utilise la config locale en cas d'erreur réseau
        final config = NotifPrefsCache.getConfig(user.tenantId);
        await CampaignScheduler.applyConfig(
          config: config,
          tenantId: user.tenantId,
        );
      }
    });
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
