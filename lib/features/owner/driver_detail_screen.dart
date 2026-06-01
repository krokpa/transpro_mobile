import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _driverProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id');
  return extractData(res.data) as Map<String, dynamic>;
});

final _scheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String id, String month})>((ref, args) async {
  final res = await ref.read(dioProvider)
      .get('/drivers/${args.id}/schedule', queryParameters: {'month': args.month});
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _absencesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id/absences');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _evaluationsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id/evaluations');
  return extractData(res.data) as Map<String, dynamic>;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverDetailScreen extends ConsumerStatefulWidget {
  final String driverId;
  const DriverDetailScreen({super.key, required this.driverId});

  @override
  ConsumerState<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends ConsumerState<DriverDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late String _month;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(_driverProvider(widget.driverId));

    return Scaffold(
      appBar: AppBar(
        title: driverAsync.when(
          loading: () => const Text('Conducteur'),
          error: (_, _) => const Text('Conducteur'),
          data: (d) => Text(
            '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Planning'),
            Tab(icon: Icon(Icons.event_busy_outlined), text: 'Absences'),
            Tab(icon: Icon(Icons.star_outline), text: 'Évaluations'),
          ],
          labelColor: brandOrange,
          indicatorColor: brandOrange,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ScheduleTab(
            driverId: widget.driverId,
            month: _month,
            onPrevMonth: () => setState(() {
              final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
              final prev = DateTime(d.year, d.month - 1);
              _month = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
            }),
            onNextMonth: () => setState(() {
              final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
              final next = DateTime(d.year, d.month + 1);
              _month = '${next.year}-${next.month.toString().padLeft(2, '0')}';
            }),
          ),
          _AbsencesTab(driverId: widget.driverId),
          _EvaluationsTab(driverId: widget.driverId),
        ],
      ),
    );
  }
}

// ── Schedule tab ──────────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  final String driverId;
  final String month;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  const _ScheduleTab({
    required this.driverId,
    required this.month,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  static const _statusCfg = {
    'SCHEDULED': (Color(0xFFDBEAFE), Color(0xFF1D4ED8), 'Planifié'),
    'BOARDING':  (Color(0xFFFEF9C3), Color(0xFFCA8A04), 'Embarquement'),
    'DEPARTED':  (Color(0xFFDCFCE7), Color(0xFF16A34A), 'Parti'),
    'ARRIVED':   (Color(0xFFF1F5F9), Color(0xFF64748B), 'Arrivé'),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), 'Annulé'),
  };

  static const _months = [
    '', 'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
  ];

  String _fmtMonth(String m) {
    final parts = m.split('-');
    if (parts.length < 2) return m;
    final y = parts[0];
    final mo = int.tryParse(parts[1]) ?? 0;
    return '${mo < _months.length ? _months[mo] : mo} $y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_scheduleProvider((id: driverId, month: month)));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevMonth,
          ),
          const SizedBox(width: 8),
          Text(_fmtMonth(month),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextMonth,
          ),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (trips) => trips.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun trajet ce mois-ci', style: TextStyle(color: Colors.grey[400])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: trips.length,
                itemBuilder: (_, i) {
                  final trip = trips[i];
                  final status = trip['status'] as String? ?? 'SCHEDULED';
                  final cfg = _statusCfg[status] ?? _statusCfg['SCHEDULED']!;
                  final dept = trip['departureTime'] as String? ?? '';
                  final route = trip['route'] as Map<String, dynamic>?;
                  final vehicle = trip['vehicle'] as Map<String, dynamic>?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: brandLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(children: [
                            Text(_fmtDay(dept),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: brandOrange)),
                            Text(_fmtMonthShort(dept),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (route != null)
                            Text('${route['origin']} → ${route['destination']}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.access_time_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Text(_fmtTime(dept),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            if (vehicle != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.directions_bus_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(vehicle['plate'] as String? ?? '',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'monospace')),
                            ],
                          ]),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(10)),
                          child: Text(cfg.$3,
                            style: TextStyle(color: cfg.$2, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      )),
    ]);
  }
}

// ── Absences tab ──────────────────────────────────────────────────────────────

class _AbsencesTab extends ConsumerWidget {
  final String driverId;
  const _AbsencesTab({required this.driverId});

  static const _typeLabel = {
    'LEAVE': 'Congé',
    'SICK':  'Maladie',
    'OTHER': 'Autre',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_absencesProvider(driverId));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Absence'),
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (absences) => absences.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune absence enregistrée', style: TextStyle(color: Colors.grey[400])),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: absences.length,
                itemBuilder: (_, i) {
                  final a = absences[i];
                  final type = a['type'] as String? ?? 'OTHER';
                  final start = a['startDate'] as String? ?? '';
                  final end = a['endDate'] as String? ?? '';
                  final reason = a['reason'] as String?;
                  final approved = a['approved'] as bool? ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: approved ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            approved ? Icons.check_circle_outline : Icons.pending_outlined,
                            color: approved ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_typeLabel[type] ?? type,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: approved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                approved ? 'Approuvée' : 'En attente',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: approved ? const Color(0xFF16A34A) : const Color(0xFFCA8A04),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 5),
                          Text('${_fmtDate(start)} — ${_fmtDate(end)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: brandDark)),
                          if (reason != null) ...[
                            const SizedBox(height: 2),
                            Text(reason, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ])),
                        Column(children: [
                          if (!approved)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
                              onPressed: () => _approve(a['id'] as String, ref, context),
                              tooltip: 'Approuver',
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFCBD5E1), size: 20),
                            onPressed: () => _delete(a['id'] as String, ref, context),
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(String absenceId, WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(dioProvider).patch('/drivers/$driverId/absences/$absenceId', data: {'approved': true});
      ref.invalidate(_absencesProvider(driverId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(String absenceId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette absence ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/drivers/$driverId/absences/$absenceId');
      ref.invalidate(_absencesProvider(driverId));
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
      builder: (_) => _AddAbsenceSheet(
        driverId: driverId,
        typeLabel: _typeLabel,
        onSaved: () => ref.invalidate(_absencesProvider(driverId)),
      ),
    );
  }
}

// ── Evaluations tab ───────────────────────────────────────────────────────────

class _EvaluationsTab extends ConsumerWidget {
  final String driverId;
  const _EvaluationsTab({required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_evaluationsProvider(driverId));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Évaluer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (data) {
                final avg = (data['averageRating'] as num?)?.toDouble() ?? 0;
                final evals = (data['evaluations'] as List?)
                    ?.cast<Map<String, dynamic>>() ?? [];

                return CustomScrollView(
            slivers: [
              if (evals.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(avg.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: brandDark)),
                            const Text('/ 5', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                          ]),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _StarRow(value: avg.round()),
                            const SizedBox(height: 4),
                            Text('${evals.length} évaluation(s)',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ])),
                        ]),
                      ),
                    ),
                  ),
                ),
              if (evals.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_outline, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Aucune évaluation', style: TextStyle(color: Colors.grey[400])),
                  ])),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final ev = evals[i];
                        final rating = ev['rating'] as int? ?? 0;
                        final punctuality = ev['punctuality'] as int?;
                        final safety = ev['safety'] as int?;
                        final service = ev['service'] as int?;
                        final comment = ev['comment'] as String?;
                        final createdAt = ev['createdAt'] as String? ?? '';
                        final evaluatedBy = ev['evaluatedBy'] as Map<String, dynamic>?;
                        final trip = ev['trip'] as Map<String, dynamic>?;
                        final route = trip?['route'] as Map<String, dynamic>?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  _StarRow(value: rating),
                                  const Spacer(),
                                  Text(_fmtDate(createdAt),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ]),
                                if (route != null) ...[
                                  const SizedBox(height: 4),
                                  Text('${route['origin']} → ${route['destination']}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ],
                                if (punctuality != null || safety != null || service != null) ...[
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 8, children: [
                                    if (punctuality != null)
                                      _MiniScore(label: 'Ponct.', value: punctuality),
                                    if (safety != null)
                                      _MiniScore(label: 'Sécu.', value: safety),
                                    if (service != null)
                                      _MiniScore(label: 'Service', value: service),
                                  ]),
                                ],
                                if (comment != null && comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(comment, style: const TextStyle(fontSize: 13, color: brandDark)),
                                ],
                                if (evaluatedBy != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Par ${evaluatedBy['firstName']} ${evaluatedBy['lastName']}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ])),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFCBD5E1), size: 20),
                                onPressed: () => _delete(ev['id'] as String, ref, context),
                              ),
                            ]),
                          ),
                        );
                      },
                      childCount: evals.length,
                    ),
                  ),
                ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String evalId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer l'évaluation ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/drivers/$driverId/evaluations/$evalId');
      ref.invalidate(_evaluationsProvider(driverId));
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
      builder: (_) => _AddEvalSheet(
        driverId: driverId,
        onSaved: () => ref.invalidate(_evaluationsProvider(driverId)),
      ),
    );
  }
}

// ── Add Absence Sheet ─────────────────────────────────────────────────────────

class _AddAbsenceSheet extends StatefulWidget {
  final String driverId;
  final Map<String, String> typeLabel;
  final VoidCallback onSaved;
  const _AddAbsenceSheet({required this.driverId, required this.typeLabel, required this.onSaved});
  @override
  State<_AddAbsenceSheet> createState() => _AddAbsenceSheetState();
}

class _AddAbsenceSheetState extends State<_AddAbsenceSheet> {
  String _type    = 'LEAVE';
  String? _start;
  String? _end;
  final _reason  = TextEditingController();
  bool _loading  = false;

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez les dates')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      await container.read(dioProvider).post('/drivers/${widget.driverId}/absences', data: {
        'startDate': _start,
        'endDate': _end,
        'type': _type,
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
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
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SheetHandle(),
        const Text("Enregistrer une absence",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: widget.typeLabel.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _DatePickerField(
            label: 'Début',
            value: _start,
            onPicked: (d) => setState(() => _start = d),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DatePickerField(
            label: 'Fin',
            value: _end,
            onPicked: (d) => setState(() => _end = d),
          )),
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
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
    );
  }
}

// ── Add Evaluation Sheet ──────────────────────────────────────────────────────

class _AddEvalSheet extends StatefulWidget {
  final String driverId;
  final VoidCallback onSaved;
  const _AddEvalSheet({required this.driverId, required this.onSaved});
  @override
  State<_AddEvalSheet> createState() => _AddEvalSheetState();
}

class _AddEvalSheetState extends State<_AddEvalSheet> {
  int _rating      = 3;
  int _punctuality = 3;
  int _safety      = 3;
  int _service     = 3;
  final _comment   = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      await container.read(dioProvider).post('/drivers/${widget.driverId}/evaluations', data: {
        'rating': _rating,
        'punctuality': _punctuality,
        'safety': _safety,
        'service': _service,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
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
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SheetHandle(),
        const Text("Évaluer le conducteur",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        const SizedBox(height: 16),
        ...[
          ('Note globale', _rating, (v) => setState(() => _rating = v)),
          ('Ponctualité', _punctuality, (v) => setState(() => _punctuality = v)),
          ('Sécurité', _safety, (v) => setState(() => _safety = v)),
          ('Service', _service, (v) => setState(() => _service = v)),
        ].map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            SizedBox(width: 110, child: Text(e.$1, style: const TextStyle(fontSize: 14, color: brandDark))),
            _StarPicker(value: e.$2, onChanged: e.$3),
          ]),
        )),
        TextFormField(
          controller: _comment,
          decoration: const InputDecoration(labelText: 'Commentaire (optionnel)'),
          maxLines: 2,
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
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int value;
  const _StarRow({required this.value});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < value ? Icons.star : Icons.star_border,
      size: 14,
      color: const Color(0xFFF59E0B),
    )),
  );
}

class _StarPicker extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  const _StarPicker({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => GestureDetector(
      onTap: () => onChanged(i + 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          i < value ? Icons.star : Icons.star_border,
          size: 28,
          color: const Color(0xFFF59E0B),
        ),
      ),
    )),
  );
}

class _MiniScore extends StatelessWidget {
  final String label;
  final int value;
  const _MiniScore({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$label $value/5',
      style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.w500)),
  );
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final void Function(String) onPicked;
  const _DatePickerField({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked.toIso8601String().substring(0, 10));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            Text(value ?? 'Non défini', style: const TextStyle(fontSize: 13)),
          ]),
        ]),
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
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ── Date helpers ──────────────────────────────────────────────────────────────

String _fmtDate(String iso) {
  if (iso.length < 10) return iso;
  final parts = iso.substring(0, 10).split('-');
  if (parts.length < 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _fmtDay(String iso) {
  if (iso.length < 10) return '—';
  return iso.substring(8, 10);
}

String _fmtTime(String iso) {
  if (iso.length < 16) return '—';
  return iso.substring(11, 16);
}

const _monthsShort = [
  '', 'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
  'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
];

String _fmtMonthShort(String iso) {
  if (iso.length < 7) return '—';
  final m = int.tryParse(iso.substring(5, 7)) ?? 0;
  return m < _monthsShort.length ? _monthsShort[m] : '—';
}
