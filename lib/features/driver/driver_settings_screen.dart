import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/space_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/legal_links.dart';
import '../../l10n/app_localizations.dart';

class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});
  @override
  ConsumerState<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final b64 = 'data:image/jpeg;base64,${base64Encode(await picked.readAsBytes())}';
      await ref.read(authProvider.notifier).updateAvatar(b64);
    } catch (_) {} finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  bool _isGuichetAccount(String email) =>
      email.contains('@guichet.transpro.ci');

  void _showChangePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ChangePasswordSheet(ref: ref),
    );
  }

  void _showSetCredentials() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SetCredentialsSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final user      = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final locale    = ref.watch(localeProvider);
    final primary   = kDriverColors.primary;

    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final isGuichet = _isGuichetAccount(user.email);

    return SpaceTheme.wrap(
      context: context,
      colors: kDriverColors,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          title: Text(l10n.navProfile,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary)),
          backgroundColor: context.cardBg,
          foregroundColor: context.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
          children: [

            // ── Avatar ─────────────────────────────────────────────────────
            Center(
              child: Column(children: [
                Stack(children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withValues(alpha: 0.4), width: 3),
                      boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.25),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: UserAvatarWidget(
                      firstName: user.firstName,
                      lastName: user.lastName,
                      avatar: user.avatar,
                      size: 80,
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                    ),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: _uploadingAvatar ? Colors.grey : primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.cardBg, width: 2),
                        ),
                        child: _uploadingAvatar
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(user.fullName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
                const SizedBox(height: 3),
                Text(user.email, style: TextStyle(fontSize: 13, color: context.textMuted)),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Informations ───────────────────────────────────────────────
            _Section(title: l10n.agentInfoSection, children: [
              _InfoTile(icon: Icons.email_outlined,
                  label: l10n.emailLabel, value: user.email, primary: primary),
              if (user.phone != null && user.phone!.isNotEmpty)
                _InfoTile(icon: Icons.phone_outlined,
                    label: l10n.phoneLabel, value: user.phone!, primary: primary),
            ]),

            const SizedBox(height: 16),

            // ── Apparence ──────────────────────────────────────────────────
            _Section(title: l10n.settingsAppearance, children: [
              ListTile(
                leading: _IconBox(icon: Icons.palette_outlined, primary: primary),
                title: Text(l10n.settingsTheme,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: ThemeMode.system,
                        child: Text(l10n.settingsThemeSystem, style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: ThemeMode.light,
                        child: Text(l10n.settingsThemeLight, style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: ThemeMode.dark,
                        child: Text(l10n.settingsThemeDark, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) { if (v != null) ref.read(themeModeProvider.notifier).setMode(v); },
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              ),
              Divider(height: 1, indent: 56, color: context.divider),
              ListTile(
                leading: _IconBox(icon: Icons.language_outlined, primary: primary),
                title: Text(l10n.settingsLanguage,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                trailing: DropdownButton<String>(
                  value: locale?.languageCode ?? 'system',
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: 'system',
                        child: Text(l10n.languageAuto, style: const TextStyle(fontSize: 13))),
                    ...localeLabels.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) {
                    if (v == null || v == 'system') ref.read(localeProvider.notifier).setLocale(null);
                    else ref.read(localeProvider.notifier).setLocale(Locale(v));
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Identifiants de connexion ──────────────────────────────────
            _Section(
              title: l10n.profileAccountSettings,
              children: [
                // Compte guichet : définir email + mdp pour la première fois
                if (isGuichet) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: context.isDark ? 0.12 : 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vous êtes connecté via téléphone. Définissez un email et un mot de passe pour vous connecter normalement.',
                          style: TextStyle(fontSize: 12, color: primary, height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                  ListTile(
                    leading: _IconBox(icon: Icons.email_outlined, primary: primary),
                    title: Text('Définir mes identifiants',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    subtitle: Text('Email + mot de passe',
                        style: TextStyle(fontSize: 12, color: context.textMuted)),
                    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
                    onTap: _showSetCredentials,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  ),
                ] else ...[
                  // Compte normal : changer le mot de passe
                  ListTile(
                    leading: _IconBox(icon: Icons.lock_outline, primary: primary),
                    title: Text(l10n.settingsChangePassword,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
                    onTap: _showChangePassword,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  ),
                ],
              Divider(height: 1, indent: 56, color: context.divider),
              FutureBuilder<BiometricType?>(
                future: resolveAvailableBiometric(),
                builder: (_, snap) {
                  final type = snap.data;
                  if (type == null) return const SizedBox.shrink();
                  final label = type == BiometricType.face
                      ? 'Face ID'
                      : type == BiometricType.iris ? 'Iris' : 'Empreinte digitale';
                  return SwitchListTile(
                    secondary: _IconBox(icon: biometricIcon(type), primary: primary),
                    title: Text(label,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
                    subtitle: Text(authState.biometricEnabled ? 'Activée' : 'Désactivée',
                        style: TextStyle(fontSize: 12, color: context.textMuted)),
                    value: authState.biometricEnabled,
                    activeThumbColor: primary,
                    activeTrackColor: primary.withValues(alpha: 0.4),
                    onChanged: (v) => ref.read(authProvider.notifier).setBiometricEnabled(v),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  );
                },
              ),
            ]),

            const SizedBox(height: 16),
            const LegalLinksSection(),
            const SizedBox(height: 16),

            // ── Déconnexion ────────────────────────────────────────────────
            Card(
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                ),
                title: Text(l10n.settingsLogout,
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
          color: context.textSecondary, letterSpacing: 0.5)),
    ),
    Card(child: Column(children: children)),
  ]);
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color primary;
  const _IconBox({required this.icon, required this.primary});
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: primary.withValues(alpha: context.isDark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: primary, size: 18),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color primary;
  const _InfoTile({required this.icon, required this.label,
      required this.value, required this.primary});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: _IconBox(icon: icon, primary: primary),
    title: Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
    subtitle: Text(value,
        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );
}

// ── Définir email + mot de passe (compte guichet/téléphone) ──────────────────

class _SetCredentialsSheet extends StatefulWidget {
  final WidgetRef ref;
  const _SetCredentialsSheet({required this.ref});
  @override
  State<_SetCredentialsSheet> createState() => _SetCredentialsSheetState();
}

class _SetCredentialsSheetState extends State<_SetCredentialsSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _pwdCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false, _showPwd = false, _showConfirm = false;

  @override
  void dispose() {
    _emailCtrl.dispose(); _pwdCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(authProvider.notifier).setCredentials(
        email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        password: _pwdCtrl.text.isEmpty ? null : _pwdCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identifiants enregistrés — vous pouvez maintenant vous connecter par email.'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Mes identifiants de connexion',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.textPrimary)),
            const SizedBox(height: 6),
            Text('Définissez un email et un mot de passe pour vous connecter sur n\'importe quel appareil.',
                style: TextStyle(fontSize: 13, color: context.textMuted, height: 1.5)),
            const SizedBox(height: 24),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Adresse email',
                prefixIcon: Icon(Icons.email_outlined),
                hintText: 'vous@email.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // optionnel si mdp fourni
                if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Mot de passe
            TextFormField(
              controller: _pwdCtrl,
              obscureText: !_showPwd,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileNewPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'Minimum 8 caractères',
                suffixIcon: IconButton(
                  icon: Icon(_showPwd ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPwd = !_showPwd),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null; // optionnel si email fourni
                if (v.length < 8) return l10n.profilePasswordMin;
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirmer mot de passe
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.profileConfirmNewPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) {
                if (_pwdCtrl.text.isNotEmpty && v != _pwdCtrl.text) return l10n.passwordMismatch;
                return null;
              },
            ),

            // Validation globale : au moins un des deux champs doit être rempli
            const SizedBox(height: 20),
            Builder(builder: (ctx) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () {
                    // Vérification : email ou mot de passe requis
                    if (_emailCtrl.text.trim().isEmpty && _pwdCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Renseignez au moins l\'email ou le mot de passe')),
                      );
                      return;
                    }
                    _save();
                  },
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }
}

// ── Changement de mot de passe ────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordSheet({required this.ref});
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPwd  = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false, _showCur = false, _showNew = false, _showCon = false;

  @override
  void dispose() { _current.dispose(); _newPwd.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(authProvider.notifier).changePassword(
          currentPassword: _current.text, newPassword: _newPwd.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe modifié'),
              backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: context.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(l10n.settingsChangePassword,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20,
                    color: context.textPrimary)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _current, obscureText: !_showCur,
              decoration: InputDecoration(
                labelText: l10n.profileCurrentPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showCur ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCur = !_showCur),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPwd, obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: l10n.profileNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.required;
                if (v.length < 6) return l10n.profilePasswordMin;
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm, obscureText: !_showCon,
              decoration: InputDecoration(
                labelText: l10n.profileConfirmNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showCon ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCon = !_showCon),
                ),
              ),
              validator: (v) => v != _newPwd.text ? l10n.passwordMismatch : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.settingsChangePassword),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
