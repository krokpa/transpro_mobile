import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../models/models.dart';
import '../api/api_client.dart';

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
      final token = results[0];
      final refresh = results[1];
      final userJson = results[2];
      final pinHash = results[3];
      final bioEnabled = results[4];
      if (token != null && userJson != null) {
        final user = User.fromJson(jsonDecode(userJson));
        state = AuthState(
          user: user,
          accessToken: token,
          refreshToken: refresh,
          isLoading: false,
          hasPinSet: pinHash != null,
          pinVerified: false,
          biometricEnabled: bioEnabled == '1',
        );
        return;
      }
    } catch (_) {}
    state = const AuthState(isLoading: false);
  }

  Future<void> login(String email, String password) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
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

    state = AuthState(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      isLoading: false,
      hasPinSet: pinHash != null,
      pinVerified: false,
      biometricEnabled: bioEnabled == '1',
    );
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
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Déverrouillez TransPro avec votre biométrie',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) state = state.copyWith(pinVerified: true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
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
    final updated = User.fromJson(res.data);
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
    try {
      await dio.post('/auth/logout', data: {'refreshToken': state.refreshToken});
    } catch (_) {}
    await Future.wait([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
      _storage.delete(key: 'user'),
      _storage.delete(key: 'pin_hash'),
      _storage.delete(key: 'biometric_enabled'),
    ]);
    state = const AuthState(isLoading: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
