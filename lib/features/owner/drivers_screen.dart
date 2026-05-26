import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final _driversProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/drivers');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_driversProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conducteurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_driversProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (drivers) => drivers.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun conducteur', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un conducteur'),
                ),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: drivers.length,
                itemBuilder: (_, i) => _DriverCard(
                  driver: drivers[i],
                  onToggle: (id, activate) => _toggle(id, activate, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _toggle(String id, bool activate, WidgetRef ref, BuildContext context) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/drivers/$id', data: {'isActive': activate});
      ref.invalidate(_driversProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDriverSheet(ref: ref),
    );
  }
}

// ── Driver card ───────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final void Function(String, bool) onToggle;
  const _DriverCard({required this.driver, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final id        = driver['id'] as String;
    final firstName = driver['firstName'] as String? ?? '';
    final lastName  = driver['lastName']  as String? ?? '';
    final phone     = driver['phone']     as String? ?? '—';
    final license   = driver['licenseNumber'] as String? ?? '—';
    final isActive  = (driver['isActive'] as bool?) ?? true;
    final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: isActive ? brandOrange : Colors.grey[300],
            child: Text(initials, style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firstName $lastName',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 3),
              Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 10),
              const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 3),
              Text(license, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  color: isActive ? const Color(0xFF16A34A) : Colors.grey[500],
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isActive,
                onChanged: (v) => onToggle(id, v),
                activeColor: brandOrange,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Add driver sheet ──────────────────────────────────────────────────────────

class _AddDriverSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddDriverSheet({required this.ref});
  @override
  State<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends State<_AddDriverSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _firstName  = TextEditingController();
  final _lastName   = TextEditingController();
  final _email      = TextEditingController();
  final _phone      = TextEditingController();
  final _license    = TextEditingController();
  bool _loading     = false;

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose();
    _phone.dispose(); _license.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = widget.ref.read(dioProvider);
      await dio.post('/drivers', data: {
        'firstName':     _firstName.text.trim(),
        'lastName':      _lastName.text.trim(),
        'email':         _email.text.trim(),
        'phone':         _phone.text.trim(),
        'licenseNumber': _license.text.trim(),
      });
      widget.ref.invalidate(_driversProvider);
      if (mounted) Navigator.pop(context);
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Nouveau conducteur',
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
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _license,
              decoration: const InputDecoration(labelText: "N° de permis"),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer le conducteur'),
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
