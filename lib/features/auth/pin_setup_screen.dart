import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
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
  bool _enableBiometric = false;
  bool _loading = false;
  BiometricType? _biometricType;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final type = await resolveAvailableBiometric();
    if (mounted) setState(() => _biometricType = type);
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
    final l10n = AppLocalizations.of(context);
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
          _error = l10n.pinMismatch;
          _currentPin = '';
          _isConfirming = false;
          _phase1Pin = '';
        });
      }
    }
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).setupPin(_currentPin, biometric: _enableBiometric);
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.user!.isPassenger) {
        context.go('/passenger');
      } else if (auth.user!.isAgent) context.go('/agent');
      else if (auth.user!.isDriver) context.go('/driver');
      else context.go('/owner');
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = l10n.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? l10n.pinConfirmTitle : l10n.pinSetupTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming ? l10n.pinConfirmSubtitle : l10n.pinSetupSubtitle,
                style: TextStyle(color: context.textSecondary, fontSize: 14),
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
              if (_biometricType != null && _isConfirming)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: SwitchListTile(
                    value: _enableBiometric,
                    onChanged: (v) => setState(() => _enableBiometric = v),
                    title: Text(
                      _biometricType == BiometricType.face
                          ? 'Activer Face ID'
                          : _biometricType == BiometricType.iris
                              ? "Activer la reconnaissance de l'iris"
                              : l10n.pinSetupBiometricLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(l10n.pinSetupBiometricSub),
                    activeThumbColor: brandOrange,
                    secondary: Icon(biometricIcon(_biometricType), color: brandOrange, size: 28),
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
                  child: Text(l10n.pinRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
