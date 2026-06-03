import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

class AgentProfileScreen extends ConsumerStatefulWidget {
  const AgentProfileScreen({super.key});
  @override
  ConsumerState<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends ConsumerState<AgentProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final b64 = 'data:image/jpeg;base64,${base64Encode(await picked.readAsBytes())}';
      await ref.read(authProvider.notifier).updateAvatar(b64);
    } catch (_) {} finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context);
    final user      = ref.watch(authProvider).user!;
    final themeMode = ref.watch(themeModeProvider);
    final locale    = ref.watch(localeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: brandCanvas,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: Text(l10n.profileTitle,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [brandCanvas, Color(0xFF1A3A5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -20, right: -20,
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandOrange.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          Stack(children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                                boxShadow: [BoxShadow(color: brandOrange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: UserAvatarWidget(
                                firstName: user.firstName,
                                lastName: user.lastName,
                                avatar: user.avatar,
                                size: 76,
                                onTap: _uploadingAvatar ? null : _pickAvatar,
                              ),
                            ),
                            Positioned(
                              right: 0, bottom: 0,
                              child: GestureDetector(
                                onTap: _uploadingAvatar ? null : _pickAvatar,
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: _uploadingAvatar ? Colors.grey : brandOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: _uploadingAvatar
                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(user.fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(user.email,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: brandOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: brandOrange.withValues(alpha: 0.4)),
                              ),
                              child: Text(l10n.agentRole,
                                style: const TextStyle(color: brandOrange, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                            if (user.stationName != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFCBD5E1)),
                                  const SizedBox(width: 4),
                                  Text(user.stationName!,
                                    style: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500, fontSize: 12)),
                                ]),
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Section(title: l10n.agentInfoSection, children: [
                  _InfoTile(icon: Icons.email_outlined, label: l10n.emailLabel, value: user.email),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    _InfoTile(icon: Icons.phone_outlined, label: l10n.phoneLabel, value: user.phone!),
                  if (user.stationName != null)
                    _InfoTile(icon: Icons.location_on_outlined, label: l10n.agentStationLabel, value: user.stationName!),
                ]),
                const SizedBox(height: 16),
                _Section(title: l10n.settingsAppearance, children: [
                  _AppearanceTiles(themeMode: themeMode, locale: locale, ref: ref),
                ]),
                const SizedBox(height: 16),
                _Section(title: l10n.profileAccountSettings, children: [
                  _ActionTile(
                    icon: Icons.lock_outline,
                    label: l10n.settingsChangePassword,
                    onTap: () => _showChangePassword(context, ref),
                  ),
                ]),
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
            color: context.textSecondary, letterSpacing: 0.5)),
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
    subtitle: Text(value,
        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
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
    title: Text(label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  );
}

class _AppearanceTiles extends StatelessWidget {
  final ThemeMode themeMode;
  final Locale? locale;
  final WidgetRef ref;
  const _AppearanceTiles({required this.themeMode, required this.locale, required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = locale?.languageCode ?? 'system';
    return Column(children: [
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.palette_outlined, color: brandOrange, size: 18),
        ),
        title: Text(l10n.settingsTheme,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
        trailing: DropdownButton<ThemeMode>(
          value: themeMode,
          underline: const SizedBox.shrink(),
          isDense: true,
          items: [
            DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.settingsThemeSystem, style: const TextStyle(fontSize: 13))),
            DropdownMenuItem(value: ThemeMode.light,  child: Text(l10n.settingsThemeLight,  style: const TextStyle(fontSize: 13))),
            DropdownMenuItem(value: ThemeMode.dark,   child: Text(l10n.settingsThemeDark,   style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) { if (v != null) ref.read(themeModeProvider.notifier).setMode(v); },
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      Divider(height: 1, indent: 56, color: context.divider),
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.language_outlined, color: brandOrange, size: 18),
        ),
        title: Text(l10n.settingsLanguage,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
        trailing: DropdownButton<String>(
          value: currentLocale,
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
      ),
    ]);
  }
}

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
    try {
      await widget.ref.read(authProvider.notifier).changePassword(
        currentPassword: _current.text,
        newPassword:     _newPwd.text,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePasswordChanged), backgroundColor: const Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: Colors.red,
          ),
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
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              alignment: Alignment.center,
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
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
