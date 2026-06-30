import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/legal_links.dart';
import '../../l10n/app_localizations.dart';

final _tenantProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/me');
  return extractData(res.data) as Map<String, dynamic>;
});

class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});
  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
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
    final auth       = ref.watch(authProvider);
    final user       = auth.user;
    if (user == null || !user.isOwner) return const SizedBox.shrink();
    final tenantAsync = ref.watch(_tenantProvider);
    final themeMode  = ref.watch(themeModeProvider);
    final locale     = ref.watch(localeProvider);
    final l10n       = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(slivers: [
        // ── Hero header ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: brandOrange,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Profil',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8C00), brandOrange],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: kToolbarHeight - 16),
                  Stack(alignment: Alignment.center, children: [
                    UserAvatarWidget(
                      firstName: user.firstName, lastName: user.lastName,
                      avatar: user.avatar, size: 72,
                      onTap: _uploadingAvatar ? null : _pickAvatar,
                      showEditOverlay: true,
                    ),
                    if (_uploadingAvatar)
                      const SizedBox(width: 72, height: 72,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 10),
                  Text(user.fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                    ),
                    child: Text(_roleLabel(user.role),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Company info
          tenantAsync.when(
            loading: () => Shimmer(child: Column(children: List.generate(3, (_) => const ShimmerListTile()))),
            error: (e, _) => Text('Erreur: $e'),
            data: (tenant) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Entreprise',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showEditTenantSheet(context, ref, tenant),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              ]),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _InfoRow(icon: Icons.business, label: 'Nom', value: tenant['name'] ?? '—'),
                    const Divider(height: 20),
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: tenant['email'] ?? '—'),
                    if (tenant['phone'] != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Téléphone', value: tenant['phone']),
                    ],
                    if (tenant['address'] != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.location_on_outlined, label: 'Adresse', value: tenant['address']),
                    ],
                    if (tenant['registrationNumber'] != null) ...[
                      const Divider(height: 20),
                      _InfoRow(icon: Icons.badge_outlined, label: 'RCCM', value: tenant['registrationNumber']),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Appearance
          Text(l10n.settingsAppearance,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.palette_outlined, color: brandOrange),
                title: Text(l10n.settingsTheme, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.themeSystem, style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: ThemeMode.light,  child: Text(l10n.themeLight,  style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: ThemeMode.dark,   child: Text(l10n.themeDark,   style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(themeModeProvider.notifier).setMode(v);
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.language_outlined, color: brandOrange),
                title: Text(l10n.settingsLanguage, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: DropdownButton<String>(
                  value: locale?.languageCode ?? '',
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.languageAuto, style: const TextStyle(fontSize: 13))),
                    ...localeLabels.entries.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final newLocale = v.isEmpty ? null : Locale(v);
                    ref.read(localeProvider.notifier).setLocale(newLocale);
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Notifications & campagnes
          const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
          const SizedBox(height: 8),
          Card(
            child: _ActionTile(
              icon: Icons.campaign_outlined,
              label: 'Campagnes de notifications',
              onTap: () => context.push('/owner/campaigns'),
            ),
          ),
          const SizedBox(height: 20),

          // Quick actions
          const Text('Compte',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              _ActionTile(
                icon: Icons.lock_outline,
                label: 'Changer le mot de passe',
                onTap: () => _showChangePasswordSheet(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _ActionTile(
                icon: Icons.logout,
                label: 'Se déconnecter',
                color: Colors.red,
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const LegalLinksSection(),
        ]),
      ),
    ),
  ]),
);
  }

  String _roleLabel(String role) => {
    'COMPANY_OWNER': 'Propriétaire',
    'COMPANY_ADMIN': 'Administrateur',
  }[role] ?? role;

  void _showEditTenantSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> tenant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditTenantSheet(
        tenant: tenant,
        onSaved: () {
          Navigator.pop(context);
          ref.invalidate(_tenantProvider);
        },
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangePasswordSheet(onSaved: () => Navigator.pop(context)),
    );
  }

}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: brandDark)),
    ]),
  ]);
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? const Color(0xFF64748B)),
    title: Text(label, style: TextStyle(color: color ?? brandDark, fontSize: 14)),
    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
    onTap: onTap,
  );
}

class _EditTenantSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onSaved;
  const _EditTenantSheet({required this.tenant, required this.onSaved});
  @override
  ConsumerState<_EditTenantSheet> createState() => _EditTenantSheetState();
}

class _EditTenantSheetState extends ConsumerState<_EditTenantSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.tenant['name'] as String? ?? '');
  late final _email = TextEditingController(text: widget.tenant['email'] as String? ?? '');
  late final _phone = TextEditingController(text: widget.tenant['phone'] as String? ?? '');
  late final _address = TextEditingController(text: widget.tenant['address'] as String? ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose(); _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/tenants/me', data: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        if (_phone.text.isNotEmpty) 'phone': _phone.text.trim(),
        if (_address.text.isNotEmpty) 'address': _address.text.trim(),
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20, right: 20, top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Form(
      key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Modifier l\'entreprise',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nom de l\'entreprise'),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'Téléphone', hintText: 'Optionnel'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'Adresse', hintText: 'Optionnel'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),
        ),
      ]),
    ),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _ChangePasswordSheet({required this.onSaved});
  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _current.dispose(); _newPwd.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/auth/change-password', data: {
        'currentPassword': _current.text,
        'newPassword': _newPwd.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe modifié'), backgroundColor: Color(0xFF16A34A)),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20, right: 20, top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Form(
      key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Changer le mot de passe',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _current,
          obscureText: _obscureCurrent,
          decoration: InputDecoration(
            labelText: 'Mot de passe actuel',
            suffixIcon: IconButton(
              icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPwd,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          validator: (v) => v == null || v.length < 8 ? '8 caractères minimum' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
          validator: (v) => v != _newPwd.text ? 'Les mots de passe ne correspondent pas' : null,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Changer'),
          ),
        ),
      ]),
    ),
  );
}
