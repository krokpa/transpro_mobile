import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/phone_input_field.dart';
import '../../core/services/social_auth_service.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';

// ── Login mode ────────────────────────────────────────────────────────────────

enum _LoginMode { email, phone }

// ── Screen ────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  /// Numéro pré-rempli — ouvre directement l'onglet « Téléphone »
  /// (ex. depuis l'inscription quand le numéro a déjà un compte).
  final String? initialPhone;
  const LoginScreen({super.key, this.initialPhone});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ── Mode ──
  _LoginMode _mode = _LoginMode.email;

  // ── Email ──
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // ── Phone ──
  final _phoneCtrl    = TextEditingController(); // full intl number from PhoneInputField
  bool _otpStarted    = false;

  // ── Common ──
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final phone = widget.initialPhone?.trim();
    if (phone != null && phone.isNotEmpty) {
      _mode = _LoginMode.phone;
      _phoneCtrl.text = phone;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Email login ───────────────────────────────────────────────────────────

  Future<void> _loginEmail() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      setState(() => _error = extractAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Phone — step 1 : envoyer OTP ─────────────────────────────────────────

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Entrez un numéro valide (+225...)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);

      // Vérifier que le numéro est inscrit avant d'envoyer l'OTP
      final checkRes = await dio.post('/auth/check-phone', data: {'phone': phone});
      final exists   = (extractData(checkRes.data) as Map?)?.containsKey('exists') == true
          ? (extractData(checkRes.data) as Map)['exists'] as bool
          : false;
      if (!exists) {
        setState(() {
          _error   = 'Aucun compte avec ce numéro. Inscrivez-vous d\'abord.';
          _loading = false;
        });
        return;
      }

      await dio.post('/otp/send', data: {'phone': phone});
      setState(() { _otpStarted = true; _loading = false; });
    } catch (e) {
      setState(() { _error = extractAuthError(e); _loading = false; });
    }
  }

  // ── Reset phone flow ──────────────────────────────────────────────────────

  void _resetPhone() => setState(() { _otpStarted = false; _error = null; });

  // ── Social login ───────────────────────────────────────────────────────────

  Future<void> _socialLogin(String provider) async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = provider == 'google'
          ? await SocialAuthService.signInWithGoogle()
          : await SocialAuthService.signInWithFacebook();
      if (token == null) { setState(() => _loading = false); return; }
      final dio = ref.read(dioProvider);
      final res = await dio.post('/auth/social', data: {'provider': provider, 'idToken': token});
      await ref.read(authProvider.notifier).setFromSocialLogin(extractData(res.data));
    } catch (e) {
      setState(() => _error = extractAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context);
    final mq         = MediaQuery.of(context);
    final safeBot    = mq.padding.bottom;
    final kbOpen     = mq.viewInsets.bottom > 0;
    final showFooter = !_otpStarted || _mode == _LoginMode.email;

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Background ──────────────────────────────────────────────────
        const Positioned.fill(child: AuthBackground()),

        // ── Layout ──────────────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(children: [

            // Hero : se rétracte quand le clavier s'ouvre
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: kbOpen ? 0 : mq.size.height * 0.22,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: OverflowBox(
                maxHeight: double.infinity,
                alignment: Alignment.center,
                child: const AuthLogoBlock(compact: true),
              ),
            ),

            // Card : remplit tout l'espace restant
            Expanded(
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
                child: Column(children: [

                  // ── Contenu scrollable ────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const AuthDragHandle(),
                        const SizedBox(height: 10),

                        Text(l10n.loginTitle,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
                        const SizedBox(height: 2),
                        Text(l10n.loginSubtitle,
                          style: TextStyle(color: context.textMuted, fontSize: 13)),
                        const SizedBox(height: 12),

                        _ModeToggle(
                          current: _mode,
                          onChanged: (m) => setState(() {
                            _mode = m; _error = null; _otpStarted = false;
                          }),
                        ),
                        const SizedBox(height: 12),

                        if (_error != null) ...[
                          AuthErrorBanner(message: _error!),
                          const SizedBox(height: 12),
                        ],

                        _mode == _LoginMode.email
                            ? _EmailPanel(
                                emailCtrl:       _emailCtrl,
                                passwordCtrl:    _passwordCtrl,
                                obscure:         _obscure,
                                loading:         _loading,
                                onToggleObscure: () => setState(() => _obscure = !_obscure),
                                onLogin:         _loginEmail,
                                l10n:            l10n,
                              )
                            : _otpStarted
                                ? _PhoneOtpPanel(phone: _phoneCtrl.text.trim(), onBack: _resetPhone)
                                : _PhoneEnterPanel(
                                    phoneCtrl: _phoneCtrl,
                                    loading:   _loading,
                                    onSend:    _sendOtp,
                                    l10n:      l10n,
                                  ),
                      ]),
                    ),
                  ),

                  // ── Footer ancré en bas ───────────────────────────────
                  if (showFooter)
                    Padding(
                      padding: EdgeInsets.fromLTRB(28, 0, 28, safeBot + 12),
                      child: Column(children: [
                        // Social buttons (email mode only)
                        if (_mode == _LoginMode.email && !_loading) ...[
                          Row(children: [
                            Expanded(child: Divider(color: context.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou continuer avec',
                                style: TextStyle(color: context.textMuted, fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: context.divider)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: SocialBtn(
                              onTap: () => _socialLogin('google'),
                              icon: const GoogleIcon(),
                              label: 'Google',
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: SocialBtn(
                              onTap: () => _socialLogin('facebook'),
                              icon: const FacebookIcon(),
                              label: 'Facebook',
                            )),
                          ]),
                          const SizedBox(height: 8),
                        ],
                        Row(children: [
                          Expanded(child: Divider(color: context.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(l10n.loginOr,
                              style: TextStyle(color: context.textMuted, fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: context.divider)),
                        ]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(l10n.noAccountText,
                            style: TextStyle(color: context.textSecondary, fontSize: 13.5)),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            ),
                            child: Text(l10n.registerLink,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ),
                        ]),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Toggle widget ─────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _LoginMode current;
  final ValueChanged<_LoginMode> onChanged;
  const _ModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _ChoiceCard(
          label: 'Email',
          hint: 'Mot de passe',
          icon: Icons.email_rounded,
          selected: current == _LoginMode.email,
          onTap: () => onChanged(_LoginMode.email),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ChoiceCard(
          label: 'Téléphone',
          hint: 'Code SMS',
          icon: Icons.smartphone_rounded,
          selected: current == _LoginMode.phone,
          onTap: () => onChanged(_LoginMode.phone),
        ),
      ),
    ]);
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [Color(0xFFFF8C00), brandOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected ? null : context.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? Colors.transparent : context.divider,
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: brandOrange.withValues(alpha: 0.32),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              // Icon bubble
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : brandOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : brandOrange,
                ),
              ),
              const SizedBox(width: 10),
              // Labels
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : context.textPrimary,
                    ),
                    child: Text(label),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.75)
                          : context.textMuted,
                    ),
                    child: Text(hint),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Email panel ───────────────────────────────────────────────────────────────

class _EmailPanel extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool loading;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final AppLocalizations l10n;
  const _EmailPanel({
    required this.emailCtrl, required this.passwordCtrl, required this.obscure,
    required this.loading, required this.onToggleObscure, required this.onLogin, required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller:       emailCtrl,
        keyboardType:     TextInputType.emailAddress,
        textInputAction:  TextInputAction.next,
        decoration:       InputDecoration(
          labelText:  l10n.emailLabel,
          prefixIcon: const Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 12),

      TextField(
        controller:      passwordCtrl,
        obscureText:     obscure,
        textInputAction: TextInputAction.done,
        onSubmitted:     (_) => onLogin(),
        decoration: InputDecoration(
          labelText:  l10n.passwordLabel,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: onToggleObscure,
          ),
        ),
      ),

      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => GoRouter.of(context).push('/forgot-password'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
          child: Text(l10n.forgotPasswordLink),
        ),
      ),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onLogin,
          child: loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(l10n.loginButton),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

// ── Phone enter panel (step 1) ────────────────────────────────────────────────

class _PhoneEnterPanel extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final bool loading;
  final VoidCallback onSend;
  final AppLocalizations l10n;
  const _PhoneEnterPanel({
    required this.phoneCtrl, required this.loading, required this.onSend, required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Numéro de téléphone',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary),
      ),
      const SizedBox(height: 8),
      PhoneInputField(controller: phoneCtrl),
      const SizedBox(height: 6),
      Text(
        'Un code à 6 chiffres vous sera envoyé par SMS',
        style: TextStyle(fontSize: 12, color: context.textMuted),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: loading ? null : onSend,
          icon: loading
              ? const SizedBox(height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sms_outlined, size: 18),
          label: Text(loading ? 'Envoi...' : 'Envoyer le code SMS'),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

// ── Phone OTP panel (step 2) ──────────────────────────────────────────────────

class _PhoneOtpPanel extends ConsumerStatefulWidget {
  final String phone;
  final VoidCallback onBack;
  const _PhoneOtpPanel({required this.phone, required this.onBack});

  @override
  ConsumerState<_PhoneOtpPanel> createState() => _PhoneOtpPanelState();
}

class _PhoneOtpPanelState extends ConsumerState<_PhoneOtpPanel>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _ctrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode>             _focus = List.generate(6, (_) => FocusNode());

  bool    _loading   = false;
  bool    _sending   = false;
  String? _error;
  int     _countdown = 60;
  Timer?  _timer;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end:  8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end:  6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  6.0, end:  0.0), weight: 1),
    ]).animate(_shakeCtrl);
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus[0].requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctrl) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_countdown > 0) {
        _countdown--;
      } else {
        t.cancel();
      } });
    });
  }

  Future<void> _resend() async {
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(dioProvider).post('/otp/send', data: {'phone': widget.phone});
      for (final c in _ctrl) {
        c.clear();
      }
      _focus[0].requestFocus();
      _startCountdown();
    } catch (e) {
      setState(() => _error = extractAuthError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit.length > 1) {
      final digits = digit.split('').take(6 - index).toList();
      for (int i = 0; i < digits.length; i++) {
        _ctrl[index + i].text = digits[i];
      }
      final next = (index + digits.length).clamp(0, 5);
      _focus[next].requestFocus();
      _tryLogin();
      return;
    }
    if (digit.isNotEmpty) {
      _ctrl[index].text = digit;
      if (index < 5) {
        _focus[index + 1].requestFocus();
      } else { _focus[index].unfocus(); _tryLogin(); }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrl[index].text.isEmpty && index > 0) {
      _focus[index - 1].requestFocus();
    }
  }

  void _tryLogin() {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code)) _doLogin(code);
  }

  Future<void> _doLogin(String code) async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).loginByPhone(widget.phone, code);
      // Auth state changes → GoRouter redirects automatically
    } catch (e) {
      if (mounted) {
        setState(() {
          _error  = extractAuthError(e);
          _loading = false;
        });
        for (final c in _ctrl) {
          c.clear();
        }
        _focus[0].requestFocus();
        _shakeCtrl.forward(from: 0);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Phone badge + change
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.phone_android_outlined, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.phone,
              style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onBack,
            child: Text(
              'Changer',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: brandOrange,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      Text(
        'Code à 6 chiffres',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary),
      ),
      const SizedBox(height: 10),

      // OTP boxes (shake on error) — taille adaptative au viewport
      AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0), child: child),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final boxSize = ((constraints.maxWidth / 6) - 8).clamp(32.0, 46.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => _buildBox(i, boxSize)),
            );
          },
        ),
      ),
      const SizedBox(height: 10),

      // Error / loading indicator
      Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _error != null
              ? Text(_error!,
                  key: ValueKey(_error),
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5),
                  textAlign: TextAlign.center)
              : _loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox(key: ValueKey('empty'), height: 18),
        ),
      ),
      const SizedBox(height: 12),

      // Resend / countdown
      Center(
        child: _countdown > 0
            ? Text(
                'Renvoyer dans $_countdown s',
                style: TextStyle(color: context.textMuted, fontSize: 13),
              )
            : TextButton.icon(
                onPressed: _sending ? null : _resend,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_sending ? 'Envoi...' : 'Renvoyer le code'),
                style: TextButton.styleFrom(foregroundColor: brandOrange),
              ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildBox(int i, [double size = 44]) {
    final filled   = _ctrl[i].text.isNotEmpty;
    final hasError = _error != null;
    return Container(
      width: size, height: size * 1.18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: filled
            ? brandOrange.withValues(alpha: 0.08)
            : (hasError ? const Color(0xFFFEE2E2) : context.inputFill),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled
              ? brandOrange
              : (hasError ? const Color(0xFFEF4444) : context.divider),
          width: 1.5,
        ),
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey:     (e) => _onKeyDown(i, e),
        child: TextField(
          controller:  _ctrl[i],
          focusNode:   _focus[i],
          textAlign:   TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength:   1,
          style: TextStyle(
            fontSize:   20,
            fontWeight: FontWeight.w700,
            color:      filled ? brandOrange : context.textPrimary,
          ),
          decoration: const InputDecoration(
            counterText:    '',
            border:         InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onDigitChanged(i, v),
        ),
      ),
    );
  }
}

