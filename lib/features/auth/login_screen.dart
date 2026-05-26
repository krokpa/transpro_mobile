import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

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
      setState(() => _error = _extractMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractMessage(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Erreur de connexion';
    } catch (_) {}
    return 'Erreur de connexion';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: brandCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Dark gradient hero ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brandCanvas, Color(0xFF1A2744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ──────────────────────────────────────────
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 40, right: 30,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.12),
              ),
            ),
          ),

          // ── Hero content (logo + greeting) ─────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: mq.size.height * 0.42,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: brandOrange,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brandOrange.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TRANSPRO CI',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bienvenue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Connectez-vous à votre compte',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White form card slides up ───────────────────────────────────
          Positioned(
            top: mq.size.height * 0.35,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: brandDark,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error banner
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
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 24),

                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Pas encore de compte ?", style: TextStyle(color: Colors.grey[600])),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text("S'inscrire", style: TextStyle(fontWeight: FontWeight.w700)),
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
