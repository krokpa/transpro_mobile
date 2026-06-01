import 'package:dio/dio.dart' show Dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';
import 'otp_step_widget.dart';

// ── Stepper indicator ─────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  final int n;
  final int current;
  final int total;

  const _StepDot({required this.n, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final done   = current > n;
    final active = current == n;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? brandOrange : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (n < total - 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 16,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: done ? brandOrange : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

// ── Page transition ───────────────────────────────────────────────────────────

class _SlideRoute extends PageRouteBuilder {
  final Widget page;
  final int direction;

  _SlideRoute({required this.page, required this.direction})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, anim, __, child) {
            final begin = Offset(direction > 0 ? 1.0 : -1.0, 0);
            final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween(begin: begin, end: Offset.zero).animate(curve),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
        );
}

// ── Wizard state ──────────────────────────────────────────────────────────────

class _WizardData {
  String firstName = '';
  String lastName  = '';
  String email     = '';
  String password  = '';
  String phone     = '';
  String phoneVerificationToken = '';
}

// ── Main wizard screen ────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _data = _WizardData();
  int _step = 0; // 0=identity 1=phone 2=confirm

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final heroH = mq.size.height * 0.28;

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AuthBackground(),

          // ── Header dégradé ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: heroH,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _step > 0 ? _prevStep : () => context.pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    Row(children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset('assets/images/transpro-logo.png',
                              width: 48, height: 48, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text('transpro',
                          style: TextStyle(color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 12),
                    // Stepper dots
                    Row(
                      children: List.generate(
                        3,
                        (i) => _StepDot(n: i, current: _step, total: 3),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // ── Panneau blanc bas ─────────────────────────────────────────
          Positioned(
            top: heroH - 20,
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, -8)),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: _buildStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _IdentityStep(
          key: const ValueKey(0),
          initial: _data,
          onNext: (d) {
            _data
              ..firstName = d.firstName
              ..lastName  = d.lastName
              ..email     = d.email
              ..password  = d.password;
            _nextStep();
          },
        ),
      1 => _PhoneStep(
          key: const ValueKey(1),
          dio: ref.read(dioProvider),
          onNext: (phone, token) {
            _data.phone = phone;
            _data.phoneVerificationToken = token;
            _nextStep();
          },
          onBack: _prevStep,
        ),
      _ => _ConfirmStep(
          key: const ValueKey(2),
          data: _data,
          onBack: _prevStep,
          onSubmit: () => _submit(),
        ),
    };
  }

  Future<void> _submit() async {
    try {
      await ref.read(authProvider.notifier).register(
        firstName: _data.firstName,
        lastName:  _data.lastName,
        email:     _data.email,
        phone:     _data.phone,
        password:  _data.password,
        phoneVerificationToken: _data.phoneVerificationToken,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractAuthError(e)), backgroundColor: Colors.red.shade600),
        );
      }
    }
  }
}

// ── Étape 1 : Identité ────────────────────────────────────────────────────────

class _IdentityStep extends StatefulWidget {
  final _WizardData initial;
  final void Function(_WizardData d) onNext;

  const _IdentityStep({super.key, required this.initial, required this.onNext});

  @override
  State<_IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<_IdentityStep> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  bool _obscure = true;
  bool _obscureConfirm = true;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.initial.firstName);
    _lastName  = TextEditingController(text: widget.initial.lastName);
    _email     = TextEditingController(text: widget.initial.email);
    _password  = TextEditingController(text: widget.initial.password);
    _confirm   = TextEditingController(text: widget.initial.password);
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password, _confirm]) c.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_firstName.text.trim().isEmpty) e['firstName'] = 'Requis';
    if (_lastName.text.trim().isEmpty)  e['lastName']  = 'Requis';
    if (!_email.text.contains('@'))     e['email']     = 'Email invalide';
    if (_password.text.length < 8)      e['password']  = 'Minimum 8 caractères';
    if (_confirm.text != _password.text) e['confirm']  = 'Mots de passe différents';
    return e;
  }

  void _submit() {
    final e = _validate();
    if (e.isNotEmpty) { setState(() => _errors = e); return; }
    final d = _WizardData()
      ..firstName = _firstName.text.trim()
      ..lastName  = _lastName.text.trim()
      ..email     = _email.text.trim()
      ..password  = _password.text;
    widget.onNext(d);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 20, 28, mq.viewInsets.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthDragHandle(),
          const SizedBox(height: 20),
          Text('Votre identité',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 4),
          Text('Étape 1 / 3 — Créez votre compte passager',
              style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: TextField(
              controller: _firstName,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Prénom *', errorText: _errors['firstName']),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _lastName,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Nom *', errorText: _errors['lastName']),
            )),
          ]),
          const SizedBox(height: 14),

          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email *',
              prefixIcon: const Icon(Icons.email_outlined),
              errorText: _errors['email'],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Mot de passe *',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errors['password'],
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe *',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _errors['confirm'],
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _submit,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Text('Suivant'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Étape 2 : Téléphone + OTP ─────────────────────────────────────────────────

class _PhoneStep extends StatefulWidget {
  final Dio dio;
  final void Function(String phone, String token) onNext;
  final VoidCallback onBack;

  const _PhoneStep({super.key, required this.dio, required this.onNext, required this.onBack});

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _phoneCtrl = TextEditingController();
  String? _phoneError;
  bool _otpStarted = false;
  String? _verifiedToken;

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  bool _validatePhone() {
    final v = _phoneCtrl.text.trim();
    if (v.isEmpty) { setState(() => _phoneError = 'Numéro requis'); return false; }
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(v)) {
      setState(() => _phoneError = 'Format : +2250712345678'); return false;
    }
    setState(() => _phoneError = null);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 20, 28, mq.viewInsets.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthDragHandle(),
          const SizedBox(height: 20),
          Text('Votre téléphone',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 4),
          Text('Étape 2 / 3 — Vérification par SMS',
              style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: !_otpStarted
                ? _buildPhoneInput()
                : OtpStepWidget(
                    key: ValueKey(_phoneCtrl.text),
                    phone: _phoneCtrl.text.trim(),
                    dio: widget.dio,
                    onVerified: (token) => setState(() => _verifiedToken = token),
                  ),
          ),

          const SizedBox(height: 24),

          if (_otpStarted && _verifiedToken != null)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 400),
              child: ElevatedButton(
                onPressed: () => widget.onNext(_phoneCtrl.text.trim(), _verifiedToken!),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Text('Continuer'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
              ),
            ),

          if (!_otpStarted || _verifiedToken == null) ...[
            if (!_otpStarted)
              ElevatedButton(
                onPressed: () {
                  if (_validatePhone()) setState(() => _otpStarted = true);
                },
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.sms_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Recevoir le code'),
                ]),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _otpStarted
                  ? () => setState(() { _otpStarted = false; _verifiedToken = null; })
                  : widget.onBack,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.arrow_back_rounded, size: 16),
                const SizedBox(width: 6),
                Text(_otpStarted ? 'Changer de numéro' : 'Retour'),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      key: const ValueKey('phone-input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone *',
            prefixIcon: const Icon(Icons.phone_outlined),
            hintText: '+2250712345678',
            errorText: _phoneError,
          ),
          onChanged: (_) => setState(() => _phoneError = null),
        ),
        const SizedBox(height: 8),
        Text('Format international requis : +225XXXXXXXXXX',
            style: TextStyle(color: context.textMuted, fontSize: 12)),
      ],
    );
  }
}

// ── Étape 3 : Confirmation ────────────────────────────────────────────────────

class _ConfirmStep extends StatefulWidget {
  final _WizardData data;
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;

  const _ConfirmStep({super.key, required this.data, required this.onBack, required this.onSubmit});

  @override
  State<_ConfirmStep> createState() => _ConfirmStepState();
}

class _ConfirmStepState extends State<_ConfirmStep> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthDragHandle(),
          const SizedBox(height: 20),
          Text('Confirmation',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 4),
          Text('Étape 3 / 3 — Vérifiez vos informations',
              style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 24),

          // Recap card
          Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _RecapRow(label: 'Prénom', value: d.firstName),
                _RecapRow(label: 'Nom', value: d.lastName),
                _RecapRow(label: 'Email', value: d.email),
                _RecapRow(
                  label: 'Téléphone',
                  value: d.phone,
                  badge: '✓ vérifié',
                  badgeColor: const Color(0xFF22C55E),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await widget.onSubmit();
                    if (mounted) setState(() => _loading = false);
                  },
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.person_add_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Créer mon compte'),
                  ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.onBack,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.arrow_back_rounded, size: 16),
              SizedBox(width: 6),
              Text('Retour'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final bool last;

  const _RecapRow({
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: context.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          Row(children: [
            Text(value,
                style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: TextStyle(color: badgeColor ?? Colors.green,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
