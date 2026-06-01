import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _obscure        = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _validate(AppLocalizations l10n) {
    final e = <String, String>{};
    if (_firstNameCtrl.text.trim().isEmpty)  e['firstName'] = l10n.required;
    if (_lastNameCtrl.text.trim().isEmpty)   e['lastName']  = l10n.required;
    if (!_emailCtrl.text.contains('@'))      e['email']     = l10n.validationEmailInvalid;
    if (_phoneCtrl.text.trim().length < 8)   e['phone']     = l10n.validationPhoneInvalid;
    if (_passwordCtrl.text.length < 8)       e['password']  = l10n.validationPasswordMin;
    if (_confirmCtrl.text != _passwordCtrl.text) e['confirm'] = l10n.passwordMismatch;
    return e;
  }

  Future<void> _register(AppLocalizations l10n) async {
    final errors = _validate(l10n);
    if (errors.isNotEmpty) {
      setState(() { _fieldErrors = errors; _error = null; });
      return;
    }
    setState(() { _loading = true; _error = null; _fieldErrors = {}; });
    try {
      await ref.read(authProvider.notifier).register(
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        password:  _passwordCtrl.text,
      );
    } catch (e) {
      setState(() => _error = extractAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final mq     = MediaQuery.of(context);
    final heroH  = mq.size.height * 0.30;

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AuthBackground(),

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
                      onTap: () => context.pop(),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/transpro-logo.png',
                            width: 52, height: 52, fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('transpro',
                              style: TextStyle(color: Colors.white, fontSize: 20,
                                  fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          Text(l10n.registerPassengerSubtitle,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: heroH - 20,
            bottom: 0,
            left: 0,
            right: 0,
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
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, 20, 28, mq.viewInsets.bottom + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthDragHandle(),
                    const SizedBox(height: 22),

                    Text(
                      l10n.registerFormTitle,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.registerFormSub,
                      style: TextStyle(color: context.textMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    Row(children: [
                      Expanded(child: TextField(
                        controller: _firstNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.firstNameLabel,
                          errorText: _fieldErrors['firstName'],
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _lastNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.lastNameLabel,
                          errorText: _fieldErrors['lastName'],
                        ),
                      )),
                    ]),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: _fieldErrors['email'],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.phoneLabel,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        errorText: _fieldErrors['phone'],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: _fieldErrors['password'],
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(l10n),
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: _fieldErrors['confirm'],
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _loading ? null : () => _register(l10n),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(l10n.registerButton),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ]),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        l10n.registerTerms,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
