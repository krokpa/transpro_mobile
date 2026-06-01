import 'package:flutter_test/flutter_test.dart';
import 'package:transpro_mobile/core/auth/auth_provider.dart';
import 'package:transpro_mobile/core/models/models.dart';

const _user = User(
  id: 'u1',
  firstName: 'Koffi',
  lastName: 'Yao',
  email: 'koffi@test.ci',
  role: 'PASSENGER',
);

void main() {
  group('AuthState.isAuthenticated', () {
    test('false when loading', () {
      const state = AuthState(isLoading: true);
      expect(state.isAuthenticated, isFalse);
    });

    test('false without user', () {
      const state = AuthState(isLoading: false, accessToken: 'tok');
      expect(state.isAuthenticated, isFalse);
    });

    test('false without token', () {
      const state = AuthState(isLoading: false, user: _user);
      expect(state.isAuthenticated, isFalse);
    });

    test('true with user and token', () {
      const state = AuthState(isLoading: false, user: _user, accessToken: 'tok');
      expect(state.isAuthenticated, isTrue);
    });
  });

  group('AuthState.copyWith', () {
    test('preserves unmodified fields', () {
      const original = AuthState(
        user: _user,
        accessToken: 'tok',
        isLoading: false,
        hasPinSet: true,
        pinVerified: false,
        biometricEnabled: true,
      );
      final copied = original.copyWith(pinVerified: true);
      expect(copied.pinVerified, isTrue);
      expect(copied.user, _user);
      expect(copied.accessToken, 'tok');
      expect(copied.hasPinSet, isTrue);
      expect(copied.biometricEnabled, isTrue);
      expect(copied.isLoading, isFalse);
    });

    test('can clear user state by overriding all fields', () {
      const original = AuthState(user: _user, accessToken: 'tok', isLoading: false);
      final cleared = original.copyWith(isLoading: true);
      expect(cleared.user, _user); // copyWith keeps user — full reset needs new AuthState()
      expect(cleared.isLoading, isTrue);
    });

    test('PIN verified transition reflects in state', () {
      const state = AuthState(
        user: _user,
        accessToken: 'tok',
        isLoading: false,
        hasPinSet: true,
        pinVerified: false,
      );
      final verified = state.copyWith(pinVerified: true);
      expect(verified.pinVerified, isTrue);
      expect(verified.hasPinSet, isTrue);
    });
  });
}
