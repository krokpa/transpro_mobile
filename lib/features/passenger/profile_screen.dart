import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/legal_links.dart';
import '../../l10n/app_localizations.dart';

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});
  @override
  ConsumerState<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends ConsumerState<PassengerProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await ref.read(authProvider.notifier).updateAvatar(b64);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final biometricEnabled = auth.biometricEnabled;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: brandCanvas,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              l10n.profileTitle,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 22),
                tooltip: l10n.settingsEditProfile,
                onPressed: () => _showEditProfile(context, ref),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _ProfileHeroBackground(
                user: user,
                uploadingAvatar: _uploadingAvatar,
                onPickAvatar: _pickAndUploadAvatar,
                l10n: l10n,
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Section(title: l10n.profilePersonalInfo, children: [
                  _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user.email),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    _InfoTile(icon: Icons.phone_outlined, label: l10n.phoneLabel, value: user.phone!),
                ]),
                const SizedBox(height: 16),
                _Section(title: l10n.profileAccountSettings, children: [
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    label: l10n.settingsEditProfile,
                    onTap: () => _showEditProfile(context, ref),
                  ),
                  _ActionTile(
                    icon: Icons.lock_outline,
                    label: l10n.settingsChangePassword,
                    onTap: () => _showChangePassword(context, ref),
                  ),
                ]),
                const SizedBox(height: 16),
                _Section(title: l10n.settingsAppearance, children: [
                  _ThemeToggleTile(current: themeMode, ref: ref),
                  _LanguageTile(current: locale, ref: ref),
                ]),
                const SizedBox(height: 16),
                _Section(title: 'Sécurité', children: [
                  _ActionTile(
                    icon: Icons.pin_outlined,
                    label: 'Modifier le code PIN',
                    onTap: () => context.push('/pin-setup'),
                  ),
                  _BiometricTile(enabled: biometricEnabled),
                ]),
                const SizedBox(height: 16),
                _Section(title: l10n.settingsQuickNav, children: [
                  _ActionTile(
                    icon: Icons.confirmation_num_outlined,
                    label: l10n.bookingsTitle,
                    onTap: () => context.go('/passenger/bookings'),
                  ),
                  _ActionTile(
                    icon: Icons.search_rounded,
                    label: l10n.searchButtonLabel,
                    onTap: () => context.go('/passenger/search'),
                  ),
                  _ActionTile(
                    icon: Icons.notifications_outlined,
                    label: l10n.notificationsTitle,
                    onTap: () => context.push('/passenger/notifications'),
                  ),
                  _ActionTile(
                    icon: Icons.campaign_outlined,
                    label: 'Préférences de notifications',
                    onTap: () =>
                        context.push('/passenger/notification-settings'),
                  ),
                ]),
                const SizedBox(height: 16),
                const LegalLinksSection(),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                    title: Text(l10n.settingsLogout,
                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(ref: ref),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChangePasswordSheet(ref: ref),
    );
  }

}

// ── Profile hero background ───────────────────────────────────────────────────

class _ProfileHeroBackground extends StatelessWidget {
  final User user;
  final bool uploadingAvatar;
  final VoidCallback? onPickAvatar;
  final AppLocalizations l10n;

  const _ProfileHeroBackground({
    required this.user,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [brandCanvas, Color(0xFF1A3A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Blobs décoratifs
          Positioned(
            top: -24, right: -24,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -30, left: -20,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Contenu — positionné sous la status bar et la toolbar
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar + bouton caméra
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brandOrange.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: UserAvatarWidget(
                            firstName: user.firstName,
                            lastName: user.lastName,
                            avatar: user.avatar,
                            size: 76,
                            onTap: uploadingAvatar ? null : onPickAvatar,
                          ),
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: GestureDetector(
                            onTap: uploadingAvatar ? null : onPickAvatar,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: uploadingAvatar ? Colors.grey.shade500 : brandOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Nom
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    // Email
                    Text(
                      user.email,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Rôle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: brandOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: brandOrange.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        l10n.passengerRole,
                        style: const TextStyle(
                          color: brandOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
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

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: context.textSecondary, letterSpacing: 0.5)),
    ),
    Card(child: Column(children: children)),
  ]);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: brandOrange, size: 18),
    ),
    title: Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
    subtitle: Text(value, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: brandOrange, size: 18),
    ),
    title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  );
}

// ── Settings tiles ────────────────────────────────────────────────────────────

class _ThemeToggleTile extends StatelessWidget {
  final ThemeMode current;
  final WidgetRef ref;
  const _ThemeToggleTile({required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      (ThemeMode.system, Icons.brightness_auto_outlined, l10n.themeSystem),
      (ThemeMode.light,  Icons.light_mode_outlined,      l10n.themeLight),
      (ThemeMode.dark,   Icons.dark_mode_outlined,       l10n.themeDark),
    ];
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.palette_outlined, color: brandOrange, size: 18),
      ),
      title: Text(l10n.settingsTheme, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
      trailing: DropdownButton<ThemeMode>(
        value: current,
        underline: const SizedBox.shrink(),
        alignment: Alignment.centerRight,
        isDense: true,
        items: options.map((o) => DropdownMenuItem(
          value: o.$1,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(o.$2, size: 16, color: context.textSecondary),
            const SizedBox(width: 6),
            Text(o.$3, style: const TextStyle(fontSize: 13)),
          ]),
        )).toList(),
        onChanged: (v) {
          if (v != null) ref.read(themeModeProvider.notifier).setMode(v);
        },
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Locale? current;
  final WidgetRef ref;
  const _LanguageTile({required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentCode = current?.languageCode ?? 'system';
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.language_outlined, color: brandOrange, size: 18),
      ),
      title: Text(l10n.settingsLanguage,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
      trailing: DropdownButton<String>(
        value: currentCode,
        underline: const SizedBox.shrink(),
        isDense: true,
        items: [
          DropdownMenuItem(value: 'system', child: Text(l10n.languageAuto, style: const TextStyle(fontSize: 13))),
          ...localeLabels.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 13)),
          )),
        ],
        onChanged: (v) {
          if (v == null || v == 'system') {
            ref.read(localeProvider.notifier).setLocale(null);
          } else {
            ref.read(localeProvider.notifier).setLocale(Locale(v));
          }
        },
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  final bool enabled;
  const _BiometricTile({required this.enabled});

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _toggling = false;

  Future<void> _onChanged(bool enable) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      if (enable) {
        // Vérification biométrique obligatoire avant d'activer
        final ok = await ref.read(authProvider.notifier).unlockBiometric();
        if (!mounted) return;
        if (ok) {
          await ref.read(authProvider.notifier).setBiometricEnabled(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentification biométrique échouée — activation annulée'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        await ref.read(authProvider.notifier).setBiometricEnabled(false);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context);
    final bioAsync = ref.watch(biometricTypeProvider);
    final isLoading = bioAsync.isLoading;
    final bioType   = bioAsync.valueOrNull;

    // Non disponible = hardware absent ou aucune empreinte inscrite
    final unavailable = !isLoading && bioType == null && !widget.enabled;

    final title = switch (bioType) {
      BiometricType.face => 'Déverrouillage Face ID',
      BiometricType.iris => "Déverrouillage par iris",
      _                  => l10n.settingsBiometric,
    };

    final subtitle = unavailable
        ? 'Non disponible sur cet appareil'
        : isLoading
            ? 'Vérification en cours…'
            : l10n.settingsBiometricSub;

    return SwitchListTile(
      secondary: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: unavailable ? context.divider : context.tagBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: _toggling || isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                biometricIcon(bioType),
                color: unavailable ? context.textMuted : brandOrange,
                size: 20,
              ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: unavailable ? context.textMuted : context.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.textMuted)),
      value: widget.enabled,
      activeThumbColor: brandOrange,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onChanged: (unavailable || _toggling || isLoading) ? null : _onChanged,
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final WidgetRef ref;
  const _EditProfileSheet({required this.ref});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.ref.read(authProvider).user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName  = TextEditingController(text: user?.lastName ?? '');
    _phone     = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    try {
      await widget.ref.read(authProvider.notifier).updateProfile(
        firstName: _firstName.text.trim(),
        lastName:  _lastName.text.trim(),
        phone:     _phone.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdated), backgroundColor: const Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
        );
      }
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
            _SheetHandle(),
            Text(l10n.settingsEditProfile,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.textPrimary)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _firstName,
              decoration: InputDecoration(labelText: l10n.firstNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastName,
              decoration: InputDecoration(labelText: l10n.lastNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: '${l10n.phoneLabel} (${l10n.optional})'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.profileSaveChanges),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Change password sheet ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordSheet({required this.ref});
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current  = TextEditingController();
  final _newPwd   = TextEditingController();
  final _confirm  = TextEditingController();
  bool _loading   = false;
  bool _showCur   = false;
  bool _showNew   = false;
  bool _showCon   = false;

  @override
  void dispose() {
    _current.dispose(); _newPwd.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    try {
      await widget.ref.read(authProvider.notifier).changePassword(
        currentPassword: _current.text,
        newPassword:     _newPwd.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePasswordChanged), backgroundColor: const Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
        );
      }
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
            _SheetHandle(),
            Text(l10n.settingsChangePassword,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: context.textPrimary)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _current,
              obscureText: !_showCur,
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
              controller: _newPwd,
              obscureText: !_showNew,
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
              controller: _confirm,
              obscureText: !_showCon,
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
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.settingsChangePassword),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    alignment: Alignment.center,
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)),
    ),
  );
}
