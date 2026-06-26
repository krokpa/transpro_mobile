import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'pin_widgets.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  static const _pinLength = 4;
  static const _maxAttempts = 5;

  final LocalAuthentication _auth = LocalAuthentication();

  String _currentPin = '';
  int _attempts = 0;
  bool _loading = false;
  String? _error;
  bool _biometricEnabled = false;
  BiometricType? _biometricType;

  @override
  void initState() {
    super.initState();


    _biometricEnabled = ref.read(authProvider).biometricEnabled;

    debugPrint('=== [PinLoginScreen] INIT ===');
    debugPrint('[PinLoginScreen] Biométrie activée dans le provider: $_biometricEnabled');

    if (_biometricEnabled) {
      _initBiometric();
    } else {
      debugPrint('[PinLoginScreen] Initialisation biométrique ignorée (désactivée dans les paramètres).');
    }
  }

  Future<void> _initBiometric() async {
    debugPrint('[PinLoginScreen] Démarrage de _initBiometric()...');
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;

      debugPrint('[PinLoginScreen] Hardware compatible (isDeviceSupported): $isSupported');
      debugPrint('[PinLoginScreen] Capteurs disponibles (canCheckBiometrics): $canCheck');

      if (!isSupported && !canCheck) {
        debugPrint('[PinLoginScreen] ❌ ÉCHEC: L\'appareil ne supporte pas la biométrie ou aucun capteur n\'est détecté.');
        return;
      }

      final availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('[PinLoginScreen] 📱 Biométries brutes renvoyées par l\'OS: $availableBiometrics');

      if (!mounted) {
        debugPrint('[PinLoginScreen] Widget démonté pendant la détection. Annulation.');
        return;
      }

      BiometricType? type;
      if (availableBiometrics.contains(BiometricType.face)) {
        type = BiometricType.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        type = BiometricType.fingerprint;
      } else if (availableBiometrics.contains(BiometricType.iris)) {
        type = BiometricType.iris;
      }

      if (type == null && (isSupported || canCheck)) {
        debugPrint('[PinLoginScreen] ⚠️ L\'appareil est compatible mais la liste est vide (souvent le cas sur Android avant le premier prompt). Utilisation du Fallback: fingerprint.');
        type = BiometricType.fingerprint;
      }

      debugPrint('[PinLoginScreen] 🎉 Type de biométrie retenu pour l\'UI: $type');
      setState(() => _biometricType = type);

      if (_biometricType != null) {
        debugPrint('[PinLoginScreen] Planification du déclenchement automatique de la biométrie (dans 400ms)...');
        Future.delayed(const Duration(milliseconds: 400), _tryBiometric);
      }
    } catch (e) {
      debugPrint('❌ [PinLoginScreen] ERREUR CRITIQUE dans _initBiometric(): $e');
    }
  }

  IconData _getBiometricIcon(BiometricType? type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face_rounded;
      case BiometricType.iris:
        return Icons.visibility_rounded;
      case BiometricType.fingerprint:
      default:
        return Icons.fingerprint_rounded;
    }
  }

  void _onKey(String digit) {
    if (_currentPin.length >= _pinLength || _loading || _isLocked) return;
    setState(() {
      _currentPin += digit;
      _error = null;
    });

    debugPrint('[PinLoginScreen] Chiffre saisi. PIN actuel: ${'*' * _currentPin.length}');

    if (_currentPin.length == _pinLength) {
      debugPrint('[PinLoginScreen] Taille max atteinte ($_pinLength). Lancement de la vérification du PIN...');
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  void _onBackspace() {
    if (_currentPin.isEmpty || _loading) return;
    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
    });
    debugPrint('[PinLoginScreen] Effacement. PIN actuel: ${'*' * _currentPin.length}');
  }

  bool get _isLocked => _attempts >= _maxAttempts;

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

    debugPrint('[PinLoginScreen] Envoi du PIN au authProvider...');
    final ok = await ref.read(authProvider.notifier).verifyPin(_currentPin);

    if (!mounted) return;

    if (ok) {
      debugPrint('[PinLoginScreen] ✅ PIN Correct ! Redirection...');
      _navigateToHome();
    } else {
      _attempts++;
      debugPrint('[PinLoginScreen] ❌ PIN Incorrect. Tentatives: $_attempts / $_maxAttempts');
      setState(() {
        _loading = false;
        _currentPin = '';
        _error = _isLocked
            ? l10n.pinLockedError
            : l10n.pinWrongError(_attempts, _maxAttempts);
      });
      if (_isLocked) {
        debugPrint('[PinLoginScreen] 🔒 ÉCRAN VERROUILLÉ : Nombre maximum de tentatives atteint.');
      }
    }
  }

  Future<void> _tryBiometric() async {
    if (!mounted || _loading || _isLocked) {
      debugPrint('[PinLoginScreen] _tryBiometric() annulé (LOCKED, LOADING ou UNMOUNTED)');
      return;
    }

    setState(() => _loading = true);
    debugPrint('[PinLoginScreen] 🔑 Appel de unlockBiometric() du provider (Ouverture pop-up système)...');

    final ok = await ref.read(authProvider.notifier).unlockBiometric();

    if (!mounted) return;

    if (ok) {
      debugPrint('[PinLoginScreen] ✅ Authentification biométrique réussie ! Redirection...');
      _navigateToHome();
    } else {
      debugPrint('[PinLoginScreen] ❌ Authentification biométrique annulée ou échouée.');
      setState(() => _loading = false);
    }
  }

  void _navigateToHome() {
    final auth = ref.read(authProvider);
    final user = auth.user;

    if (user == null) {
      debugPrint('[PinLoginScreen] Redirection impossible: l\'utilisateur est null.');
      context.go('/login');
      return;
    }

    if (user.isPassenger) {
      debugPrint('[PinLoginScreen] Redirection vers l\'espace PASSAGER (/passenger)');
      context.go('/passenger');
    } else if (user.isAgent) {
      debugPrint('[PinLoginScreen] Redirection vers l\'espace AGENT (/agent)');
      context.go('/agent');
    } else if (user.isDriver) {
      debugPrint('[PinLoginScreen] Redirection vers l\'espace CHAUFFEUR (/driver)');
      context.go('/driver');
    } else {
      debugPrint('[PinLoginScreen] Redirection vers l\'espace PROPRIÉTAIRE (/owner)');
      context.go('/owner');
    }
  }

  Future<void> _signOutAndLogin() async {
    debugPrint('[PinLoginScreen] Déconnexion demandée ("Se connecter avec un autre compte")');
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
                child: const Icon(
                  Icons.lock_person_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.pinLoginTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _isLocked ? l10n.pinLockedTitle : l10n.pinLoginSubtitle,
                style: TextStyle(color: theme.hintColor, fontSize: 14),
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
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: _loading ? 0.3 : 1.0,
                    child: IgnorePointer(
                      ignoring: _loading || _isLocked,
                      child: PinKeypad(
                        onKey: _onKey,
                        onBackspace: _onBackspace,
                        onBiometric: (_biometricEnabled && _biometricType != null) ? _tryBiometric : null,
                        biometricType: _biometricType,
                      ),
                    ),
                  ),
                  if (_loading) const CircularProgressIndicator(color: brandOrange),
                ],
              ),
              const SizedBox(height: 16),
              if (_biometricEnabled && _biometricType != null && !_isLocked && !_loading)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: Icon(_getBiometricIcon(_biometricType), size: 18, color: brandOrange),
                  label: Text(
                    _biometricType == BiometricType.face
                        ? 'Utiliser Face ID'
                        : _biometricType == BiometricType.iris
                        ? "Utiliser la reconnaissance de l'iris"
                        : 'Utiliser mon empreinte',
                    style: const TextStyle(color: brandOrange, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOutAndLogin,
                child: Text(l10n.pinSignInAnother),
              ),
            ],
          ),
        ),
      ),
    );
  }
}