import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/shimmer.dart';

final _schedulesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/schedules');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

final _routesForSchedulesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/routes', queryParameters: {'isActive': true});
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_schedulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horaires'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_schedulesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter un horaire',
            onPressed: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => AppShimmer.tripCards(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (schedules) => schedules.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun horaire', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un horaire'),
                ),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: schedules.length,
                itemBuilder: (_, i) => _ScheduleCard(
                  schedule: schedules[i],
                  onToggle: (id, v) => _toggle(id, v, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _toggle(String id, bool activate, WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(dioProvider).patch('/schedules/$id', data: {'isActive': activate});
      ref.invalidate(_schedulesProvider);
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
      builder: (_) => _AddScheduleSheet(ref: ref),
    );
  }
}

// ── Schedule card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final void Function(String, bool) onToggle;
  const _ScheduleCard({required this.schedule, required this.onToggle});

  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _classColors = {
    'VIP':      (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'EXPRESS':  (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'STANDARD': (Color(0xFFF0FDF4), Color(0xFF16A34A)),
  };

  @override
  Widget build(BuildContext context) {
    final id        = schedule['id'] as String;
    final route     = schedule['route'] as Map<String, dynamic>?;
    final routeName = route?['name'] as String? ??
        '${route?['originCity']?['name'] ?? ''} → ${route?['destinationCity']?['name'] ?? ''}';
    final time      = schedule['departureTime'] as String? ?? '—';
    final tripClass = schedule['tripClass'] as String? ?? 'STANDARD';
    final price     = (schedule['price'] as num?)?.toInt() ?? 0;
    final isActive  = (schedule['isActive'] as bool?) ?? true;
    final days      = (schedule['days'] as List?)?.map((d) => (d as num).toInt()).toSet() ?? <int>{};

    final classCfg = _classColors[tripClass] ?? _classColors['STANDARD']!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.schedule, color: brandOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(routeName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Text(time,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandOrange)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: classCfg.$1, borderRadius: BorderRadius.circular(6)),
                  child: Text(tripClass, style: TextStyle(color: classCfg.$2, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$price F', style: const TextStyle(fontWeight: FontWeight.w700, color: brandDark)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isActive,
                  onChanged: (v) => onToggle(id, v),
                  activeThumbColor: brandOrange,
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: List.generate(7, (i) {
            final dayNum = i + 1;
            final active = days.contains(dayNum);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: active ? brandOrange : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text(
                  _dayLabels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF94A3B8),
                  ),
                )),
              ),
            );
          })),
        ]),
      ),
    );
  }
}

// ── Add schedule sheet ────────────────────────────────────────────────────────

class _AddScheduleSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddScheduleSheet({required this.ref});
  @override
  ConsumerState<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends ConsumerState<_AddScheduleSheet> {
  final _formKey   = GlobalKey<FormState>();
  String? _routeId;
  TimeOfDay _time  = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _days = {1, 2, 3, 4, 5};
  String _tripClass = 'STANDARD';
  final _price      = TextEditingController();
  bool _loading     = false;

  static const _classes = ['STANDARD', 'EXPRESS', 'VIP'];
  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void dispose() { _price.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _routeId == null) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/schedules', data: {
        'routeId':      _routeId,
        'departureTime': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'days':          _days.toList()..sort(),
        'tripClass':     _tripClass,
        'price':         int.tryParse(_price.text) ?? 0,
      });
      ref.invalidate(_schedulesProvider);
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
    final routesAsync = ref.watch(_routesForSchedulesProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Nouvel horaire',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
            const SizedBox(height: 20),
            // Route picker
            routesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur routes: $e', style: const TextStyle(color: Colors.red)),
              data: (routes) {
                final routeItems = routes.map((r) => _RouteOption(
                  id: r['id'] as String,
                  name: r['name'] as String? ??
                      '${r['originCity']?['name'] ?? ''} → ${r['destinationCity']?['name'] ?? ''}',
                )).toList();
                return SearchableDropdownField<_RouteOption>(
                  label:     'Itinéraire',
                  hint:      'Sélectionner un itinéraire…',
                  value:     routeItems.cast<_RouteOption?>().firstWhere(
                    (r) => r?.id == _routeId, orElse: () => null),
                  items:     routeItems,
                  itemLabel: (r) => r.name,
                  itemKey:   (r) => r.id,
                  onChanged: (r) => setState(() => _routeId = r?.id),
                  validator: (v) => v == null ? 'Sélectionnez un itinéraire' : null,
                );
              },
            ),
            const SizedBox(height: 14),
            // Time picker
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Heure de départ'),
                child: Row(children: [
                  Text(_time.format(context),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.access_time, size: 18, color: Color(0xFF94A3B8)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // Days selector
            const Text('Jours', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: List.generate(7, (i) {
              final day = i + 1;
              final sel = _days.contains(day);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => sel ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: sel ? brandOrange : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(
                      _dayLabels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    )),
                  ),
                ),
              );
            })),
            const SizedBox(height: 14),
            // Class
            SearchableDropdownField<String>(
              label:     'Classe',
              value:     _tripClass,
              items:     _classes,
              itemLabel: (c) => c,
              onChanged: (v) { if (v != null) setState(() => _tripClass = v); },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Prix (FCFA)', suffixText: 'F'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer l\'horaire'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RouteOption {
  final String id;
  final String name;
  const _RouteOption({required this.id, required this.name});
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
