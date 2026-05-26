import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

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
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/register', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName':  _lastNameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim(),
        'password':  _passwordCtrl.text,
        'role': 'PASSENGER',
      });
      await ref.read(authProvider.notifier).login(
        _emailCtrl.text.trim(), _passwordCtrl.text,
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
      if (data is Map) return data['message']?.toString() ?? 'Erreur';
    } catch (_) {}
    return "Erreur lors de l'inscription";
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
            top: -40, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Hero content ────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: mq.size.height * 0.32,
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
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: brandOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('TRANSPRO CI', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                        Text('Créer un compte', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      'Rejoignez des milliers de voyageurs',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White form card ─────────────────────────────────────────────
          Positioned(
            top: mq.size.height * 0.26,
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
                      'Vos informations',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandDark),
                    ),
                    const SizedBox(height: 20),

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

                    Row(children: [
                      Expanded(child: TextField(
                        controller: _firstNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _lastNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      )),
                    ]),
                    const SizedBox(height: 14),
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
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Créer mon compte'),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Text(
                        'En créant un compte, vous acceptez nos conditions d\'utilisation.',
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
