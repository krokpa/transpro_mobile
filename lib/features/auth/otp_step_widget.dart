import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Widget OTP réutilisable : envoi automatique + saisie 6 cases + resend.
class OtpStepWidget extends StatefulWidget {
  final String phone;
  final Dio dio;
  final void Function(String token) onVerified;

  const OtpStepWidget({
    super.key,
    required this.phone,
    required this.dio,
    required this.onVerified,
  });

  @override
  State<OtpStepWidget> createState() => _OtpStepWidgetState();
}

class _OtpStepWidgetState extends State<OtpStepWidget> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _ctrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  bool _sent = false;
  bool _sending = false;
  bool _verifying = false;
  bool _verified = false;
  String? _error;
  int _countdown = 0;
  Timer? _timer;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
    _sendOtp();
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
    setState(() => _countdown = 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdown--;
        if (_countdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    setState(() { _sending = true; _error = null; });
    try {
      await widget.dio.post('/otp/send', data: {'phone': widget.phone});
      if (mounted) {
        setState(() { _sent = true; _sending = false; });
        _startCountdown();
        WidgetsBinding.instance.addPostFrameCallback((_) => _focus[0].requestFocus());
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['message'] ?? 'Erreur d\'envoi du code';
          _sending = false;
        });
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit.length > 1) {
      // Paste multi-chiffres
      final digits = digit.split('').take(6 - index).toList();
      for (int i = 0; i < digits.length; i++) {
        _ctrl[index + i].text = digits[i];
      }
      final next = (index + digits.length).clamp(0, 5);
      _focus[next].requestFocus();
      _tryVerify();
      return;
    }
    if (digit.isNotEmpty) {
      _ctrl[index].text = digit;
      if (index < 5) {
        _focus[index + 1].requestFocus();
      } else {
        _focus[index].unfocus();
        _tryVerify();
      }
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrl[index].text.isEmpty &&
        index > 0) {
      _focus[index - 1].requestFocus();
    }
  }

  void _tryVerify() {
    final code = _ctrl.map((c) => c.text).join();
    if (code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code)) {
      _verify(code);
    }
  }

  Future<void> _verify(String code) async {
    setState(() { _verifying = true; _error = null; });
    try {
      final res = await widget.dio.post('/otp/verify', data: {'phone': widget.phone, 'code': code});
      final token = (extractData(res.data))['phoneVerificationToken'] as String;
      if (mounted) {
        setState(() { _verified = true; _verifying = false; });
        widget.onVerified(token);
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['message'] ?? 'Code incorrect';
        setState(() { _error = msg; _verifying = false; });
        for (final c in _ctrl) {
          c.clear();
        }
        _focus[0].requestFocus();
        _shakeCtrl.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 52),
          const SizedBox(height: 12),
          const Text('Numéro vérifié !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
          const SizedBox(height: 6),
          Text(widget.phone,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        ],
      );
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _sending
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 60,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Column(
                  key: const ValueKey('otp'),
                  children: [
                    Text(
                      'Code envoyé au',
                      style: TextStyle(color: context.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.phone,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) => _buildBox(i)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _error != null
                          ? Text(
                              _error!,
                              key: ValueKey(_error),
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                              textAlign: TextAlign.center,
                            )
                          : _verifying
                              ? const SizedBox(
                                  key: ValueKey('verifying'),
                                  height: 20,
                                  child: Center(
                                    child: SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              : const SizedBox(key: ValueKey('empty'), height: 20),
                    ),
                    const SizedBox(height: 16),
                    if (_sent)
                      _countdown > 0
                          ? Text(
                              'Renvoyer dans $_countdown s',
                              style: TextStyle(color: context.textMuted, fontSize: 13),
                            )
                          : TextButton.icon(
                              onPressed: _sending ? null : _sendOtp,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Renvoyer le code'),
                              style: TextButton.styleFrom(foregroundColor: brandOrange),
                            ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBox(int i) {
    final filled = _ctrl[i].text.isNotEmpty;
    final hasError = _error != null;
    return Container(
      width: 44,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: filled
            ? brandOrange.withValues(alpha: 0.08)
            : (hasError ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled
              ? brandOrange
              : (hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) => _onKeyDown(i, e),
        child: TextField(
          controller: _ctrl[i],
          focusNode: _focus[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: filled ? brandOrange : context.textPrimary,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onDigitChanged(i, v),
        ),
      ),
    );
  }
}
