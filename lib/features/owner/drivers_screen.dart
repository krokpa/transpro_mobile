import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/view_toggle_button.dart';

final _driversProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res   = await ref.read(dioProvider).get('/drivers');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

String _fmtDateShort(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d);
    const m = ['', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
                'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${dt.day} ${m[dt.month]} ${dt.year}';
  } catch (_) { return d.substring(0, 10); }
}

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final _search = TextEditingController();
  String _filter = 'all'; // all | available | unavailable
  bool _isGrid = false;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_driversProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Chauffeurs',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          ViewToggleButton(
            isGrid: _isGrid,
            onToggle: (v) => setState(() => _isGrid = v),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_driversProvider),
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddSheet(context),
            tooltip: 'Ajouter un chauffeur',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (drivers) {
          // Summary stats
          final total     = drivers.length;
          final available = drivers.where((d) => d['isAvailable'] as bool? ?? true).length;
          final expiring  = drivers.where((d) {
            final exp = d['licenseExpiry'] as String?;
            if (exp == null) return false;
            try {
              final days = DateTime.parse(exp).difference(DateTime.now()).inDays;
              return days >= 0 && days <= 60;
            } catch (_) { return false; }
          }).length;

          // Filter & search
          final query = _search.text.toLowerCase();
          final filtered = drivers.where((d) {
            final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.toLowerCase();
            final phone = (d['phone'] as String? ?? '').toLowerCase();
            final license = (d['licenseNumber'] as String? ?? '').toLowerCase();
            final matchSearch = query.isEmpty || name.contains(query) || phone.contains(query) || license.contains(query);
            final isAvail = d['isAvailable'] as bool? ?? true;
            final matchFilter = _filter == 'all' || (_filter == 'available' && isAvail) || (_filter == 'unavailable' && !isAvail);
            return matchSearch && matchFilter;
          }).toList();

          if (drivers.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_off_outlined, size: 72, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Aucun chauffeur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              const SizedBox(height: 8),
              Text('Ajoutez votre premier chauffeur', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _showAddSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un chauffeur'),
                style: FilledButton.styleFrom(backgroundColor: brandOrange),
              ),
            ]));
          }

          return CustomScrollView(
            slivers: [
              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    _SummaryChip(label: 'Total', value: '$total', color: brandOrange),
                    const SizedBox(width: 10),
                    _SummaryChip(label: 'Disponibles', value: '$available', color: const Color(0xFF22C55E)),
                    const SizedBox(width: 10),
                    if (expiring > 0)
                      _SummaryChip(label: 'Permis ⚠', value: '$expiring', color: const Color(0xFFF59E0B)),
                  ]),
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un chauffeur…',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      suffixIcon: _search.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16), onPressed: () => setState(() => _search.clear()))
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ),

              // Filter chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in [
                        ('all', 'Tous', total),
                        ('available', 'Disponibles', available),
                        ('unavailable', 'Indisponibles', total - available),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${f.$2} (${f.$3})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _filter == f.$1 ? Colors.white : const Color(0xFF475569),
                              )),
                            selected: _filter == f.$1,
                            onSelected: (_) => setState(() => _filter = f.$1),
                            selectedColor: brandOrange,
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: BorderSide(color: _filter == f.$1 ? brandOrange : Color(0xFFE2E8F0)),
                            showCheckmark: false,
                          ),
                        ),
                    ]),
                  ),
                ),
              ),

              // List / Grid
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  _isGrid ? 12 : 16, 12,
                  _isGrid ? 12 : 16, 100,
                ),
                sliver: filtered.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Aucun résultat', style: TextStyle(color: Colors.grey[400])),
                            ]),
                          ),
                        ),
                      )
                    : _isGrid
                        ? SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.88,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _DriverGridCard(
                                driver: filtered[i],
                                onToggle: (id, val) => _toggle(id, val),
                                onDetail: (id) => context.push('/owner/drivers/$id'),
                              ),
                              childCount: filtered.length,
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _DriverCard(
                                driver: filtered[i],
                                onToggle: (id, val) => _toggle(id, val),
                                onDetail: (id) => context.push('/owner/drivers/$id'),
                              ),
                              childCount: filtered.length,
                            ),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _toggle(String id, bool val) async {
    try {
      await ref.read(dioProvider).patch('/drivers/$id', data: {'isAvailable': val});
      ref.invalidate(_driversProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDriverSheet(
        onSaved: () => ref.invalidate(_driversProvider),
      ),
    );
  }
}

// ── Summary chip ───────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Driver grid card ──────────────────────────────────────────────────────────

class _DriverGridCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final void Function(String, bool) onToggle;
  final void Function(String) onDetail;
  const _DriverGridCard({required this.driver, required this.onToggle, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final id        = driver['id']        as String;
    final firstName = driver['firstName'] as String? ?? '';
    final lastName  = driver['lastName']  as String? ?? '';
    final isAvail   = driver['isAvailable'] as bool? ?? true;
    final expiry    = driver['licenseExpiry'] as String?;
    final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    bool expired = false;
    if (expiry != null) {
      try { expired = DateTime.parse(expiry).isBefore(DateTime.now()); } catch (_) {}
    }

    return GestureDetector(
      onTap: () => onDetail(id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: expired ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Avatar + status dot
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: isAvail
                      ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)])
                      : null,
                  color: isAvail ? null : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(initials, style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isAvail ? Colors.white : const Color(0xFF94A3B8),
                ))),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: isAvail ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '$firstName\n$lastName',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAvail ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAvail ? 'Disponible' : 'Indisponible',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isAvail ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (expired) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                child: const Text('Permis expiré',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              ),
            ],
            const Spacer(),
            // Toggle availability
            GestureDetector(
              onTap: () => onToggle(id, !isAvail),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isAvail ? const Color(0xFFF1F5F9) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAvail ? 'Rendre indispo.' : 'Rendre dispo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: isAvail ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Driver list card ──────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final void Function(String, bool) onToggle;
  final void Function(String) onDetail;
  const _DriverCard({required this.driver, required this.onToggle, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final id        = driver['id'] as String;
    final firstName = driver['firstName'] as String? ?? '';
    final lastName  = driver['lastName']  as String? ?? '';
    final phone     = driver['phone']     as String? ?? '—';
    final license   = driver['licenseNumber'] as String? ?? '—';
    final expiry    = driver['licenseExpiry'] as String?;
    final isAvail   = driver['isAvailable'] as bool? ?? true;
    final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    // License status
    int? daysToExpiry;
    bool expired = false, warn = false;
    if (expiry != null) {
      try {
        daysToExpiry = DateTime.parse(expiry).difference(DateTime.now()).inDays;
        expired = daysToExpiry < 0;
        warn = !expired && daysToExpiry <= 60;
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => onDetail(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: expired
            ? const Color(0xFFFECACA)
            : warn ? const Color(0xFFFED7AA) : const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: isAvail
                      ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)])
                      : null,
                  color: isAvail ? null : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(initials,
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: isAvail ? Colors.white : const Color(0xFF94A3B8),
                  ))),
              ),
              if (!isAvail)
                Positioned(bottom: -3, right: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle),
                    child: const Icon(Icons.pause, size: 8, color: Colors.white),
                  )),
              if (isAvail)
                Positioned(bottom: -3, right: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                  )),
            ]),
            const SizedBox(width: 14),

            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$firstName $lastName',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(license, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
              ]),

              // License expiry warning
              if (expired || warn) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: expired ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_amber_rounded, size: 11,
                      color: expired ? const Color(0xFFDC2626) : const Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Text(
                      expired
                          ? 'Permis expiré'
                          : 'Permis expire dans ${daysToExpiry}j · ${_fmtDateShort(expiry)}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: expired ? const Color(0xFFDC2626) : const Color(0xFFEA580C)),
                    ),
                  ]),
                ),
              ],
            ])),

            // Actions
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Switch(
                value: isAvail,
                onChanged: (v) => onToggle(id, v),
                activeThumbColor: brandOrange,
                activeTrackColor: brandOrange.withValues(alpha: 0.4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => onDetail(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text('Voir →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: brandOrange)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Add driver sheet ───────────────────────────────────────────────────────────

class _AddDriverSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddDriverSheet({required this.onSaved});

  @override
  ConsumerState<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends ConsumerState<_AddDriverSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licCtrl   = TextEditingController();
  DateTime? _licenseExpiry;
  bool _loading = false;

  @override
  void dispose() {
    _firstCtrl.dispose(); _lastCtrl.dispose();
    _phoneCtrl.dispose(); _licCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenseExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez la date d'expiration du permis"), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/drivers', data: {
        'firstName':     _firstCtrl.text.trim(),
        'lastName':      _lastCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
        'licenseNumber': _licCtrl.text.trim(),
        'licenseExpiry': _licenseExpiry!.toIso8601String(),
      });
      widget.onSaved();
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Nouveau chauffeur',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
            const SizedBox(height: 4),
            const Text('Renseignez les informations du chauffeur',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: _Field(controller: _firstCtrl, label: 'Prénom *',
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null)),
              const SizedBox(width: 12),
              Expanded(child: _Field(controller: _lastCtrl, label: 'Nom *',
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null)),
            ]),
            const SizedBox(height: 14),
            _Field(controller: _phoneCtrl, label: 'Téléphone *',
              keyboardType: TextInputType.phone,
              hint: '+225 07 XX XX XX',
              validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 14),
            _Field(controller: _licCtrl, label: 'N° Permis de conduire *',
              hint: 'CI-DRV-2024-XXXXX',
              validator: (v) => v!.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 14),

            // License expiry
            GestureDetector(
              onTap: _pickExpiry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 16,
                    color: _licenseExpiry != null ? brandOrange : Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  Text(
                    _licenseExpiry != null
                        ? 'Expiration permis : ${_fmtDateShort(_licenseExpiry!.toIso8601String())}'
                        : 'Date d\'expiration du permis *',
                    style: TextStyle(fontSize: 13,
                      color: _licenseExpiry != null ? brandDark : const Color(0xFF94A3B8)),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: brandOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer le chauffeur',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _Field({required this.controller, required this.label, this.hint, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: brandOrange, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}
