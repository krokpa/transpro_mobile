import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'pin_widgets.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  static const _pinLength = 4;
  static const _maxAttempts = 5;

  String _currentPin = '';
  int _attempts = 0;
  bool _loading = false;
  String? _error;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = ref.read(authProvider).biometricEnabled;
    if (_biometricEnabled) {
      Future.delayed(const Duration(milliseconds: 400), _tryBiometric);
    }
  }

  void _onKey(String digit) {
    if (_currentPin.length >= _pinLength || _loading || _isLocked) return;
    setState(() { _currentPin += digit; _error = null; });
    if (_currentPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  void _onBackspace() {
    if (_currentPin.isEmpty || _loading) return;
    setState(() => _currentPin = _currentPin.substring(0, _currentPin.length - 1));
  }

  bool get _isLocked => _attempts >= _maxAttempts;

  Future<void> _verify() async {
    setState(() => _loading = true);
    final ok = await ref.read(authProvider.notifier).verifyPin(_currentPin);
    if (!mounted) return;
    if (ok) {
      _navigateToHome();
    } else {
      setState(() {
        _attempts++;
        _loading = false;
        _currentPin = '';
        _error = _isLocked
            ? 'Trop de tentatives échouées. Utilisez votre mot de passe.'
            : 'Code PIN incorrect ($_attempts/$_maxAttempts tentatives)';
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted || _loading) return;
    setState(() => _loading = true);
    final ok = await ref.read(authProvider.notifier).unlockBiometric();
    if (!mounted) return;
    if (ok) {
      _navigateToHome();
    } else {
      setState(() => _loading = false);
    }
  }

  void _navigateToHome() {
    final auth = ref.read(authProvider);
    if (auth.user!.isPassenger) context.go('/passenger');
    else if (auth.user!.isAgent) context.go('/agent');
    else context.go('/owner');
  }

  Future<void> _signOutAndLogin() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_person_outlined, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              const Text(
                'Code PIN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: brandDark),
              ),
              const SizedBox(height: 8),
              Text(
                _isLocked
                    ? 'Compte verrouillé'
                    : 'Saisissez votre code à 4 chiffres',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pinLength,
                  (i) => PinDot(filled: i < _currentPin.length),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _error != null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _error ?? '',
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator()
              else if (!_isLocked)
                PinKeypad(
                  onKey: _onKey,
                  onBackspace: _onBackspace,
                  onBiometric: _biometricEnabled ? _tryBiometric : null,
                ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _signOutAndLogin,
                child: const Text('Se connecter autrement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
