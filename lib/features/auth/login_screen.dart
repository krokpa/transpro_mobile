import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context);
    final mq       = MediaQuery.of(context);
    final heroH    = mq.size.height * 0.38;
    final safeBot  = mq.padding.bottom;

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 18, 28, safeBot + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthDragHandle(),
                    const SizedBox(height: 16),

                    Text(
                      l10n.loginTitle,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.loginSubtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),

                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        ),
                        child: Text(l10n.forgotPasswordLink),
                      ),
                    ),
                    const SizedBox(height: 4),

                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(l10n.loginButton),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ]),
                    ),

                    const Spacer(),

                    Row(children: [
                      Expanded(child: Divider(color: context.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(l10n.loginOr, style: TextStyle(color: context.textMuted, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: context.divider)),
                    ]),
                    const SizedBox(height: 10),

                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(l10n.noAccountText, style: TextStyle(color: context.textSecondary, fontSize: 13.5)),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        child: Text(l10n.registerLink,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    ]),
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
