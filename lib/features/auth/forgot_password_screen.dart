import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

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

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/forgot-password', data: {'email': _emailCtrl.text.trim()});
      setState(() => _sent = true);
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brandCanvas, Color(0xFF1A2744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Hero
          Positioned(
            top: 0, left: 0, right: 0,
            height: mq.size.height * 0.30,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mot de passe\noublié ?',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entrez votre email pour recevoir un lien.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form card
          Positioned(
            top: mq.size.height * 0.25,
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24, 28, 24,
                  mq.viewInsets.bottom + 32,
                ),
                child: _sent ? _SuccessView() : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Adresse email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Envoyer le lien de réinitialisation'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Si cet email est enregistré, vous recevrez un lien.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
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

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
        child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF16A34A), size: 42),
      ),
      const SizedBox(height: 20),
      const Text('Email envoyé !',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandDark)),
      const SizedBox(height: 10),
      const Text(
        'Si cet email est enregistré, vous\nrecevrez un lien de réinitialisation.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B), height: 1.5),
      ),
      const SizedBox(height: 32),
      Text(
        'Vérifiez également votre dossier spam.',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    ]),
  );
}
