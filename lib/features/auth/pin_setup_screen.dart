import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'pin_widgets.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  static const _pinLength = 4;

  String _phase1Pin = '';
  String _currentPin = '';
  bool _isConfirming = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _enableBiometric = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await ref.read(authProvider.notifier).isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  void _onKey(String digit) {
    if (_currentPin.length >= _pinLength || _loading) return;
    setState(() { _currentPin += digit; _error = null; });
    if (_currentPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 150), _advance);
    }
  }

  void _onBackspace() {
    if (_currentPin.isEmpty) return;
    setState(() => _currentPin = _currentPin.substring(0, _currentPin.length - 1));
  }

  void _advance() {
    if (!_isConfirming) {
      setState(() {
        _phase1Pin = _currentPin;
        _currentPin = '';
        _isConfirming = true;
      });
    } else {
      if (_currentPin == _phase1Pin) {
        _complete();
      } else {
        setState(() {
          _error = 'Les codes PIN ne correspondent pas. Réessayez.';
          _currentPin = '';
          _isConfirming = false;
          _phase1Pin = '';
        });
      }
    }
  }

  Future<void> _complete() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).setupPin(_currentPin, biometric: _enableBiometric);
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.user!.isPassenger) context.go('/passenger');
      else if (auth.user!.isAgent) context.go('/agent');
      else context.go('/owner');
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur lors de la configuration.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirmez votre code PIN' : 'Choisissez un code PIN',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: brandDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Saisissez à nouveau le même code à 4 chiffres'
                    : 'Ce code sécurisera l\'accès à l\'application',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
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
                child: Text(
                  _error ?? '',
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              if (_biometricAvailable && _isConfirming)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: SwitchListTile(
                    value: _enableBiometric,
                    onChanged: (v) => setState(() => _enableBiometric = v),
                    title: const Text(
                      'Activer la biométrie',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('Empreinte digitale / Face ID'),
                    activeColor: brandOrange,
                    secondary: const Icon(Icons.fingerprint, color: brandOrange),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else
                PinKeypad(onKey: _onKey, onBackspace: _onBackspace),
              const SizedBox(height: 24),
              if (_isConfirming)
                TextButton(
                  onPressed: () => setState(() {
                    _isConfirming = false;
                    _phase1Pin = '';
                    _currentPin = '';
                    _error = null;
                  }),
                  child: const Text('Recommencer'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
