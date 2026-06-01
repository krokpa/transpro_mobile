import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '_auth_shared.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _error = l10n.validationEmailInvalid);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/forgot-password', data: {'email': _emailCtrl.text.trim()});
      setState(() => _sent = true);
    } catch (_) {
      setState(() => _error = l10n.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final mq    = MediaQuery.of(context);
    final heroH = mq.size.height * 0.36;

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
                          Text(l10n.forgotPasswordTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text(l10n.forgotPasswordSubtitle,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 24),
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
                child: _sent ? _SuccessContent(l10n: l10n) : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthDragHandle(),
                    const SizedBox(height: 22),

                    Text(
                      l10n.forgotPasswordTitle,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.forgotInstruction,
                      style: TextStyle(color: context.textMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(l10n),
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _loading ? null : () => _submit(l10n),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l10n.sendResetLink),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        l10n.forgotSentBody,
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

class _SuccessContent extends StatelessWidget {
  final AppLocalizations l10n;
  const _SuccessContent({required this.l10n});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
        child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF16A34A), size: 40),
      ),
      const SizedBox(height: 20),
      Text(l10n.forgotSentTitle,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 10),
      Text(
        l10n.forgotSentBody,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textSecondary, height: 1.5, fontSize: 14),
      ),
      const SizedBox(height: 28),
      Text(
        l10n.forgotSpamNote,
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
    ]),
  );
}
