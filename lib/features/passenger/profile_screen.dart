import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class PassengerProfileScreen extends ConsumerWidget {
  const PassengerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final initials = '${user.firstName[0]}${user.lastName[0]}'.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: brandCanvas,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: const Text('Mon profil', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
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
                          const SizedBox(height: 32),
                          Container(
                            width: 76, height: 76,
                            decoration: BoxDecoration(
                              color: brandOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: brandOrange.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(initials,
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(user.fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(user.email,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: brandOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: brandOrange.withValues(alpha: 0.4)),
                            ),
                            child: const Text('Passager',
                              style: TextStyle(color: brandOrange, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Section(title: 'Informations personnelles', children: [
                  _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user.email),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    _InfoTile(icon: Icons.phone_outlined, label: 'Téléphone', value: user.phone!),
                ]),
                const SizedBox(height: 16),
                _Section(title: 'Paramètres du compte', children: [
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Modifier le profil',
                    onTap: () => _showEditProfile(context, ref),
                  ),
                  _ActionTile(
                    icon: Icons.lock_outline,
                    label: 'Changer le mot de passe',
                    onTap: () => _showChangePassword(context, ref),
                  ),
                ]),
                const SizedBox(height: 16),
                _Section(title: 'Navigation rapide', children: [
                  _ActionTile(
                    icon: Icons.confirmation_num_outlined,
                    label: 'Mes billets',
                    onTap: () => context.go('/passenger/bookings'),
                  ),
                  _ActionTile(
                    icon: Icons.search_rounded,
                    label: 'Rechercher un voyage',
                    onTap: () => context.go('/passenger/search'),
                  ),
                  _ActionTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => context.push('/passenger/notifications'),
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
                    title: const Text('Déconnexion',
                      style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                    onTap: () => _confirmLogout(context, ref),
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

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Déconnecter'),
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
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
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
      decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: brandOrange, size: 18),
    ),
    title: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
    subtitle: Text(value, style: const TextStyle(color: brandDark, fontWeight: FontWeight.w600, fontSize: 14)),
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
      decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: brandOrange, size: 18),
    ),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: brandDark)),
    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  );
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
    final user = widget.ref.read(authProvider).user!;
    _firstName = TextEditingController(text: user.firstName);
    _lastName  = TextEditingController(text: user.lastName);
    _phone     = TextEditingController(text: user.phone ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.ref.read(authProvider.notifier).updateProfile(
        firstName: _firstName.text.trim(),
        lastName:  _lastName.text.trim(),
        phone:     _phone.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Modifier le profil',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: brandDark)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer les modifications'),
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
    try {
      await widget.ref.read(authProvider.notifier).changePassword(
        currentPassword: _current.text,
        newPassword:     _newPwd.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe modifié'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Changer le mot de passe',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: brandDark)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _current,
              obscureText: !_showCur,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                suffixIcon: IconButton(
                  icon: Icon(_showCur ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCur = !_showCur),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPwd,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: !_showCon,
              decoration: InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(_showCon ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCon = !_showCon),
                ),
              ),
              validator: (v) => v != _newPwd.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Modifier le mot de passe'),
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
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
    ),
  );
}
