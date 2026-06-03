import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/phone_input_field.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';

// ── Login mode ────────────────────────────────────────────────────────────────

enum _LoginMode { email, phone }

// ── Screen ────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
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
      await dio.post('/otp/send', data: {'phone': phone});
      setState(() { _otpStarted = true; _loading = false; });
    } catch (e) {
      setState(() { _error = extractAuthError(e); _loading = false; });
    }
  }

  // ── Reset phone flow ──────────────────────────────────────────────────────

  void _resetPhone() => setState(() { _otpStarted = false; _error = null; });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context);
    final mq      = MediaQuery.of(context);
    final heroH   = mq.size.height * 0.38;
    final safeBot = mq.padding.bottom;

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        const AuthBackground(),
        Positioned(
          top: 0, left: 0, right: 0,
          height: heroH,
          child: SafeArea(
            bottom: false,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [AuthLogoBlock()],
            ),
          ),
        ),
        Positioned(
          top: heroH - 24,
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 18, 28, safeBot + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthDragHandle(),
                  const SizedBox(height: 16),

                  Text(
                    l10n.loginTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.loginSubtitle,
                    style: TextStyle(color: context.textMuted, fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),

                  // ── Toggle Email / Téléphone ──────────────────────────────
                  _ModeToggle(
                    current: _mode,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _error = null;
                      _otpStarted = false;
                    }),
                  ),
                  const SizedBox(height: 16),

                  // ── Error ─────────────────────────────────────────────────
                  if (_error != null) ...[
                    AuthErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],

                  // ── Content ───────────────────────────────────────────────
                  Expanded(
                    child: _mode == _LoginMode.email
                        ? _EmailPanel(
                            emailCtrl:    _emailCtrl,
                            passwordCtrl: _passwordCtrl,
                            obscure:      _obscure,
                            loading:      _loading,
                            onToggleObscure: () => setState(() => _obscure = !_obscure),
                            onLogin:      _loginEmail,
                            l10n:         l10n,
                          )
                        : _otpStarted
                            ? _PhoneOtpPanel(
                                phone:  _phoneCtrl.text.trim(),
                                onBack: _resetPhone,
                              )
                            : _PhoneEnterPanel(
                                phoneCtrl: _phoneCtrl,
                                loading:   _loading,
                                onSend:    _sendOtp,
                                l10n:      l10n,
                              ),
                  ),

                  // ── Footer ────────────────────────────────────────────────
                  if (!_otpStarted || _mode == _LoginMode.email) ...[
                    Row(children: [
                      Expanded(child: Divider(color: context.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          l10n.loginOr,
                          style: TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                      ),
                      Expanded(child: Divider(color: context.divider)),
                    ]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(
                        l10n.noAccountText,
                        style: TextStyle(color: context.textSecondary, fontSize: 13.5),
                      ),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        child: Text(
                          l10n.registerLink,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
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
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _Tab(label: 'Email',     icon: Icons.email_outlined,    selected: current == _LoginMode.email,
             onTap: () => onChanged(_LoginMode.email)),
        _Tab(label: 'Téléphone', icon: Icons.phone_android_outlined, selected: current == _LoginMode.phone,
             onTap: () => onChanged(_LoginMode.phone)),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:        selected ? brandOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: selected ? Colors.white : context.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      selected ? Colors.white : context.textMuted,
              ),
            ),
          ]),
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
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
          child: Text(l10n.forgotPasswordLink),
        ),
      ),
      const SizedBox(height: 4),

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
      const Spacer(),
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
      const Spacer(),
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
    for (final c in _ctrl)  c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (_countdown > 0) _countdown--; else t.cancel(); });
    });
  }

  Future<void> _resend() async {
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(dioProvider).post('/otp/send', data: {'phone': widget.phone});
      for (final c in _ctrl) c.clear();
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
      for (int i = 0; i < digits.length; i++) _ctrl[index + i].text = digits[i];
      final next = (index + digits.length).clamp(0, 5);
      _focus[next].requestFocus();
      _tryLogin();
      return;
    }
    if (digit.isNotEmpty) {
      _ctrl[index].text = digit;
      if (index < 5) _focus[index + 1].requestFocus();
      else { _focus[index].unfocus(); _tryLogin(); }
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
        for (final c in _ctrl) c.clear();
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

      // OTP boxes (shake on error)
      AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0), child: child),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _buildBox(i)),
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
      const Spacer(),
    ]);
  }

  Widget _buildBox(int i) {
    final filled   = _ctrl[i].text.isNotEmpty;
    final hasError = _error != null;
    return Container(
      width: 44, height: 52,
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
