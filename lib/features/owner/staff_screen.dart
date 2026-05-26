import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final _staffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/users', queryParameters: {
    'roles': 'COMPANY_AGENT,COMPANY_ADMIN',
  });
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

final _stationsForStaffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/stations');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_staffProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_staffProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteSheet(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Inviter'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (staff) => staff.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_off_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun membre du personnel', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showInviteSheet(context, ref),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Inviter un agent'),
                ),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: staff.length,
                itemBuilder: (_, i) => _StaffCard(
                  member: staff[i],
                  onToggle: (id, v) => _toggle(id, v, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _toggle(String id, bool activate, WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(dioProvider).patch('/users/$id', data: {'isActive': activate});
      ref.invalidate(_staffProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InviteStaffSheet(ref: ref),
    );
  }
}

// ── Staff card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final void Function(String, bool) onToggle;
  const _StaffCard({required this.member, required this.onToggle});

  static const _roleCfg = {
    'COMPANY_AGENT': (Color(0xFFEFF6FF), Color(0xFF2563EB), 'Agent'),
    'COMPANY_ADMIN': (Color(0xFFF5F3FF), Color(0xFF7C3AED), 'Admin'),
  };

  @override
  Widget build(BuildContext context) {
    final id        = member['id'] as String;
    final firstName = member['firstName'] as String? ?? '';
    final lastName  = member['lastName']  as String? ?? '';
    final email     = member['email']     as String? ?? '—';
    final role      = member['role']      as String? ?? 'COMPANY_AGENT';
    final isActive  = (member['isActive'] as bool?) ?? true;
    final stations  = member['userStations'] as List?;
    final station   = stations?.firstWhere(
      (s) => s['isPrimary'] == true,
      orElse: () => stations.isNotEmpty ? stations.first : null,
    );
    final stationName = station?['station']?['name'] as String?;
    final roleCfg = _roleCfg[role] ?? _roleCfg['COMPANY_AGENT']!;
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: isActive ? roleCfg.$1 : Colors.grey[100],
            child: Text(
              initials,
              style: TextStyle(color: isActive ? roleCfg.$2 : Colors.grey[400], fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$firstName $lastName',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: roleCfg.$1, borderRadius: BorderRadius.circular(6)),
                child: Text(roleCfg.$3,
                  style: TextStyle(color: roleCfg.$2, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (stationName != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 2),
                Text(stationName, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
            ],
          ])),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isActive,
              onChanged: (v) => onToggle(id, v),
              activeColor: brandOrange,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Invite staff sheet ────────────────────────────────────────────────────────

class _InviteStaffSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _InviteStaffSheet({required this.ref});
  @override
  ConsumerState<_InviteStaffSheet> createState() => _InviteStaffSheetState();
}

class _InviteStaffSheetState extends ConsumerState<_InviteStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email   = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  String _role   = 'COMPANY_AGENT';
  String? _stationId;
  bool _loading  = false;

  @override
  void dispose() { _email.dispose(); _firstName.dispose(); _lastName.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/users/invite', data: {
        'email':     _email.text.trim(),
        'firstName': _firstName.text.trim(),
        'lastName':  _lastName.text.trim(),
        'role':      _role,
        if (_stationId != null) 'stationId': _stationId,
      });
      ref.invalidate(_staffProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation envoyée'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
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
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(_stationsForStaffProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Inviter un membre',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              )),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Email invalide' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(value: 'COMPANY_AGENT', child: Text('Agent guichet')),
                DropdownMenuItem(value: 'COMPANY_ADMIN', child: Text('Administrateur')),
              ],
              onChanged: (v) { if (v != null) setState(() => _role = v); },
            ),
            const SizedBox(height: 14),
            stationsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stations) => DropdownButtonFormField<String>(
                value: _stationId,
                decoration: const InputDecoration(labelText: 'Gare assignée (optionnel)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                  ...stations.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(s['name'] as String? ?? ''),
                  )),
                ],
                onChanged: (v) => setState(() => _stationId = v),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer l\'invitation'),
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
    margin: const EdgeInsets.only(bottom: 16),
    alignment: Alignment.center,
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
    ),
  );
}
