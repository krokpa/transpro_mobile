import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/space_theme.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/app_error_view.dart';

final _driverProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/me');
  return extractData(res.data) as Map<String, dynamic>;
});

final _driverEvalsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/evaluations');
  return extractData(res.data) as Map<String, dynamic>;
});

final _driverAbsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/absences');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _logout() async {
    try { await ref.read(dioProvider).post('/auth/logout'); } catch (_) {}
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final meAsync   = ref.watch(_driverProfileProvider);
    final evalsAsync = ref.watch(_driverEvalsProvider);
    final absAsync  = ref.watch(_driverAbsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: meAsync.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => AppErrorView(error: e),
        data: (data) {
          final driver = data['driver'] as Map<String, dynamic>?;
          final stats  = data['stats'] as Map<String, dynamic>?;
          if (driver == null) return const SizedBox.shrink();

          final firstName = driver['firstName'] as String? ?? '';
          final lastName  = driver['lastName']  as String? ?? '';
          final phone     = driver['phone']     as String? ?? '';
          final license   = driver['licenseNumber'] as String? ?? '';
          final expiry    = driver['licenseExpiry'] as String?;
          final isAvail   = driver['isAvailable'] as bool? ?? true;
          final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

          int? daysToExpiry;
          bool licenseExpired = false;
          if (expiry != null) {
            try { daysToExpiry = DateTime.parse(expiry).difference(DateTime.now()).inDays; licenseExpired = daysToExpiry < 0; } catch (_) {}
          }

          final primary = context.spacePrimary;

          return Column(
            children: [
              // ── Header gradient fixe ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(primary, Colors.black, 0.18)!,
                      primary,
                      Color.lerp(primary, Colors.white, 0.14)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Barre d'actions (top row)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white),
                            onPressed: () => context.push('/driver/settings'),
                            tooltip: 'Paramètres',
                          ),
                        ],
                      ),

                      // Identité + disponibilité
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: Row(children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                              boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: UserAvatarWidget(
                              firstName: firstName,
                              lastName: lastName,
                              avatar: ref.watch(authProvider).user?.avatar,
                              size: 60,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$firstName $lastName',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(phone, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          ])),
                          GestureDetector(
                            onTap: () async {
                              await ref.read(dioProvider).patch('/driver-space/availability', data: {'isAvailable': !isAvail});
                              ref.invalidate(_driverProfileProvider);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isAvail ? Colors.white : Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 6, height: 6, decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAvail ? const Color(0xFF22C55E) : Colors.white54,
                                )),
                                const SizedBox(width: 5),
                                Text(isAvail ? 'Disponible' : 'Indisp.', style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: isAvail ? primary : Colors.white70,
                                )),
                              ]),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 12),

                      // Permis
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: licenseExpired
                                ? const Color(0xFFFEE2E2)
                                : (daysToExpiry != null && daysToExpiry <= 60)
                                    ? const Color(0xFFFFF7ED)
                                    : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              licenseExpired ? Icons.warning_amber_rounded : Icons.verified_outlined,
                              size: 13,
                              color: licenseExpired
                                  ? const Color(0xFFDC2626)
                                  : (daysToExpiry != null && daysToExpiry <= 60)
                                      ? const Color(0xFFEA580C)
                                      : Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              licenseExpired
                                  ? 'Permis expiré · $license'
                                  : expiry != null
                                      ? 'Permis $license · exp. ${_fmtDate(expiry)}'
                                      : 'Permis $license',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: licenseExpired
                                    ? const Color(0xFFDC2626)
                                    : (daysToExpiry != null && daysToExpiry <= 60)
                                        ? const Color(0xFFEA580C)
                                        : Colors.white,
                              ),
                            ),
                          ]),
                        ),
                      ),

                      if (stats != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            _PillStat(label: 'Voyages total', value: '${stats['tripsTotal'] ?? 0}'),
                            const SizedBox(width: 8),
                            _PillStat(label: 'Note', value: stats['avgRating'] != null
                                ? '${(stats['avgRating'] as num).toStringAsFixed(1)}/5' : '—'),
                            const SizedBox(width: 8),
                            _PillStat(label: 'Réalisation', value: stats['completionRate'] != null
                                ? '${stats['completionRate']}%' : '—'),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),

              // ── TabBar clairement séparé du header ───────────────────────
              Material(
                color: Colors.white,
                elevation: 1,
                shadowColor: Colors.black12,
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: primary,
                  indicatorWeight: 3,
                  labelColor: primary,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.star_outline_rounded, size: 16), text: 'Évaluations'),
                    Tab(icon: Icon(Icons.event_busy_outlined, size: 16), text: 'Absences'),
                  ],
                ),
              ),

              // ── Contenu onglets ──────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // Évaluations
                    evalsAsync.when(
                      loading: () => AppShimmer.listTiles(),
                      error: (e, _) => AppErrorView(error: e),
                      data: (edata) {
                        final avg   = (edata['averageRating'] as num?)?.toDouble();
                        final evals = (edata['evaluations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        if (evals.isEmpty) {
                          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_outline_rounded, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Aucune évaluation', style: TextStyle(color: Colors.grey[400])),
                        ]));
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            if (avg != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Row(children: [
                                  Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: brandDark, height: 1)),
                                  const SizedBox(width: 12),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _starRow(avg.round()),
                                    const SizedBox(height: 4),
                                    Text('/5 · ${evals.length} évaluation${evals.length > 1 ? "s" : ""}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  ]),
                                ]),
                              ),
                            ...evals.map((ev) => _EvalCard(ev: ev)),
                          ],
                        );
                      },
                    ),

                    // Absences
                    _AbsencesTab(
                      absAsync: absAsync,
                      onDeclare: () => _showAbsenceSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAbsenceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AbsenceSheet(
        onSaved: () {
          ref.invalidate(_driverAbsProvider);
          ref.invalidate(_driverProfileProvider);
        },
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label, value;
  const _PillStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.24))),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
      ]),
    ),
  );
}

Widget _starRow(int value) => Row(
  mainAxisSize: MainAxisSize.min,
  children: List.generate(5, (i) => Icon(
    i < value ? Icons.star_rounded : Icons.star_outline_rounded,
    size: 16, color: i < value ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
  )),
);

class _EvalCard extends StatelessWidget {
  final Map<String, dynamic> ev;
  const _EvalCard({required this.ev});

  @override
  Widget build(BuildContext context) {
    final rating = (ev['rating'] as num?)?.toInt() ?? 0;
    final comment = ev['comment'] as String?;
    final createdAt = ev['createdAt'] as String?;
    final evaluatedBy = ev['evaluatedBy'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _starRow(rating),
          const SizedBox(width: 6),
          Text('$rating/5', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark)),
          const Spacer(),
          Text(_fmtDate(createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Text('"$comment"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: brandDark)),
          ),
        ],
        if (evaluatedBy != null) ...[
          const SizedBox(height: 6),
          Text('Par ${evaluatedBy['firstName']} ${evaluatedBy['lastName']}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ]),
    );
  }
}

class _AbsencesTab extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> absAsync;
  final VoidCallback onDeclare;
  const _AbsencesTab({required this.absAsync, required this.onDeclare});

  static const _typeLabel = {'LEAVE': 'Congé', 'SICK': 'Maladie', 'OTHER': 'Autre'};
  static const _typeColor = {
    'LEAVE': Color(0xFF3B82F6), 'SICK': Color(0xFFEF4444), 'OTHER': Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    floatingActionButton: Builder(builder: (ctx) => FloatingActionButton.extended(
      onPressed: onDeclare,
      backgroundColor: SpaceTheme.of(ctx).primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Déclarer', style: TextStyle(fontWeight: FontWeight.w600)),
    )),
    body: absAsync.when(
      loading: () => AppShimmer.listTiles(),
      error: (e, _) => AppErrorView(error: e),
      data: (absences) => absences.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Aucune absence', style: TextStyle(color: Colors.grey[400])),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: absences.length,
              itemBuilder: (_, i) {
                final a        = absences[i];
                final type     = a['type'] as String? ?? 'OTHER';
                final approved = a['approved'] as bool? ?? false;
                final start    = a['startDate'] as String?;
                final end      = a['endDate'] as String?;
                final reason   = a['reason'] as String?;
                final color    = _typeColor[type] ?? const Color(0xFF94A3B8);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(children: [
                    Container(width: 4, height: 70,
                      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                    const SizedBox(width: 12),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(_typeLabel[type] ?? type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: approved ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(approved ? '✓ Approuvée' : '⏳ En attente',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: approved ? const Color(0xFF16A34A) : const Color(0xFFEA580C))),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('${_fmtDate(start)} — ${_fmtDate(end)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandDark)),
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(reason, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ]),
                    )),
                    const SizedBox(width: 12),
                  ]),
                );
              },
            ),
    ),
  );
}

class _AbsenceSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AbsenceSheet({required this.onSaved});

  @override
  ConsumerState<_AbsenceSheet> createState() => _AbsenceSheetState();
}

class _AbsenceSheetState extends ConsumerState<_AbsenceSheet> {
  String _type = 'LEAVE';
  DateTime? _start, _end;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now()),
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() { if (isStart) {
      _start = picked;
    } else {
      _end = picked;
    } });
    }
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/driver-space/absences', data: {
        'startDate': _start!.toIso8601String(),
        'endDate':   _end!.toIso8601String(),
        'type':      _type,
        'reason':    _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
      );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Déclarer une absence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
        const SizedBox(height: 20),

        Row(children: [
          for (final e in {'LEAVE': 'Congé', 'SICK': 'Maladie', 'OTHER': 'Autre'}.entries)
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => setState(() => _type = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _type == e.key ? SpaceTheme.of(context).primary : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _type == e.key ? SpaceTheme.of(context).primary : const Color(0xFFE2E8F0)),
                  ),
                  child: Center(child: Text(e.value, style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: _type == e.key ? Colors.white : const Color(0xFF475569),
                  ))),
                ),
              ),
            )),
        ]),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _DatePick(label: 'Début', value: _start, onTap: () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _DatePick(label: 'Fin', value: _end, onTap: () => _pickDate(false))),
        ]),
        const SizedBox(height: 14),

        TextField(
          controller: _reasonCtrl,
          decoration: InputDecoration(
            labelText: 'Motif (optionnel)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity, height: 48,
          child: FilledButton(
            onPressed: (_start == null || _end == null || _loading) ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: SpaceTheme.of(context).primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    ),
  );
}

class _DatePick extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DatePick({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value != null ? _fmtDate(value!.toIso8601String()) : 'Choisir',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: value != null ? brandDark : const Color(0xFF94A3B8))),
      ]),
    ),
  );
}

String _fmtDate(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    const months = ['', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  } catch (_) { return '—'; }
}
