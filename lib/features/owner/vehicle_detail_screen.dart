import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _vehicleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/vehicles/$id');
  return extractData(res.data) as Map<String, dynamic>;
});

final _fuelLogsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/vehicles/$id/fuel-logs');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _maintenanceLogsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/vehicles/$id/maintenance-logs');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class VehicleDetailScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(_vehicleProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: vehicleAsync.when(
          loading: () => const Text('Véhicule'),
          error: (_, __) => const Text('Véhicule'),
          data: (v) => Text(
            '${v['plate'] ?? ''} · ${v['brand'] ?? ''} ${v['model'] ?? ''}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.local_gas_station_outlined), text: 'Carburant'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Entretien'),
          ],
          labelColor: brandOrange,
          indicatorColor: brandOrange,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FuelTab(vehicleId: widget.vehicleId),
          _MaintenanceTab(vehicleId: widget.vehicleId),
        ],
      ),
    );
  }
}

// ── Fuel tab ──────────────────────────────────────────────────────────────────

class _FuelTab extends ConsumerWidget {
  final String vehicleId;
  const _FuelTab({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_fuelLogsProvider(vehicleId));

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: () => _showAddFuelSheet(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Plein'),
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (logs) => logs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_gas_station_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucun plein enregistré', style: TextStyle(color: Colors.grey[400])),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => _FuelLogCard(
                        log: logs[i],
                        onDelete: () => _deleteLog(logs[i]['id'] as String, ref, context),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(String logId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce plein ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/vehicles/$vehicleId/fuel-logs/$logId');
      ref.invalidate(_fuelLogsProvider(vehicleId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddFuelSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddFuelSheet(
        vehicleId: vehicleId,
        onSaved: () => ref.invalidate(_fuelLogsProvider(vehicleId)),
      ),
    );
  }
}

class _FuelLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onDelete;
  const _FuelLogCard({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = log['date'] as String? ?? '';
    final liters = (log['liters'] as num?)?.toDouble() ?? 0;
    final totalCost = log['totalCost'] as int? ?? 0;
    final odometer = log['odometer'] as int?;
    final station = log['station'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_gas_station_outlined, color: brandOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${liters.toStringAsFixed(1)} L',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
              const Spacer(),
              Text('${totalCost.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} F CFA',
                style: const TextStyle(fontWeight: FontWeight.w700, color: brandOrange)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(_fmtDate(date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (odometer != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.speed_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('$odometer km', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
              if (station != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.place_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 2),
                Text(station, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ]),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFCBD5E1), size: 20),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }
}

// ── Maintenance tab ───────────────────────────────────────────────────────────

class _MaintenanceTab extends ConsumerWidget {
  final String vehicleId;
  const _MaintenanceTab({required this.vehicleId});

  static const _typeLabel = {
    'OIL_CHANGE':    'Vidange',
    'TIRE_ROTATION': 'Rotation pneus',
    'BRAKE_SERVICE': 'Freins',
    'FILTER_CHANGE': 'Filtre',
    'MAJOR_SERVICE': 'Révision majeure',
    'REPAIR':        'Réparation',
    'INSPECTION':    'Inspection',
    'OTHER':         'Autre',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_maintenanceLogsProvider(vehicleId));

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
                  label: const Text('Entretien'),
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (logs) => logs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.build_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucun entretien enregistré', style: TextStyle(color: Colors.grey[400])),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => _MaintenanceLogCard(
                        log: logs[i],
                        typeLabel: _typeLabel,
                        onDelete: () => _deleteLog(logs[i]['id'] as String, ref, context),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(String logId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet entretien ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/vehicles/$vehicleId/maintenance-logs/$logId');
      ref.invalidate(_maintenanceLogsProvider(vehicleId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
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
      builder: (_) => _AddMaintenanceSheet(
        vehicleId: vehicleId,
        typeLabel: _typeLabel,
        onSaved: () => ref.invalidate(_maintenanceLogsProvider(vehicleId)),
      ),
    );
  }
}

class _MaintenanceLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Map<String, String> typeLabel;
  final VoidCallback onDelete;
  const _MaintenanceLogCard({required this.log, required this.typeLabel, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = log['type'] as String? ?? 'OTHER';
    final label = typeLabel[type] ?? type;
    final date = log['date'] as String? ?? '';
    final desc = log['description'] as String? ?? '';
    final cost = log['cost'] as int?;
    final odometer = log['odometer'] as int?;
    final nextDue = log['nextDueAt'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.build_outlined, color: Color(0xFFEA580C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              if (cost != null)
                Text('${cost.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} F',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: brandOrange, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 13, color: brandDark)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(_fmtDate(date), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (odometer != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.speed_outlined, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text('$odometer km', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ]),
            if (nextDue != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.event_outlined, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text('Prochain: ${_fmtDate(nextDue)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w500)),
              ]),
            ],
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFCBD5E1), size: 20),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }
}

// ── Add Fuel Sheet ────────────────────────────────────────────────────────────

class _AddFuelSheet extends StatefulWidget {
  final String vehicleId;
  final VoidCallback onSaved;
  const _AddFuelSheet({required this.vehicleId, required this.onSaved});
  @override
  State<_AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends State<_AddFuelSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _liters    = TextEditingController();
  final _total     = TextEditingController();
  final _odometer  = TextEditingController();
  final _station   = TextEditingController();
  String _date     = DateTime.now().toIso8601String().substring(0, 10);
  bool _loading    = false;

  @override
  void dispose() {
    _liters.dispose(); _total.dispose(); _odometer.dispose(); _station.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      await container.read(dioProvider).post('/vehicles/${widget.vehicleId}/fuel-logs', data: {
        'date': _date,
        'liters': double.parse(_liters.text.trim()),
        'totalCost': int.parse(_total.text.trim()),
        if (_odometer.text.trim().isNotEmpty) 'odometer': int.parse(_odometer.text.trim()),
        if (_station.text.trim().isNotEmpty) 'station': _station.text.trim(),
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
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SheetHandle(),
          const Text('Enregistrer un plein',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked.toIso8601String().substring(0, 10));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(_date, style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _liters,
              decoration: const InputDecoration(labelText: 'Litres', suffixText: 'L'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _total,
              decoration: const InputDecoration(labelText: 'Coût total', suffixText: 'F'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _odometer,
              decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _station,
              decoration: const InputDecoration(labelText: 'Station'),
            )),
          ]),
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
}

// ── Add Maintenance Sheet ─────────────────────────────────────────────────────

class _AddMaintenanceSheet extends StatefulWidget {
  final String vehicleId;
  final Map<String, String> typeLabel;
  final VoidCallback onSaved;
  const _AddMaintenanceSheet({required this.vehicleId, required this.typeLabel, required this.onSaved});
  @override
  State<_AddMaintenanceSheet> createState() => _AddMaintenanceSheetState();
}

class _AddMaintenanceSheetState extends State<_AddMaintenanceSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _desc        = TextEditingController();
  final _cost        = TextEditingController();
  final _odometer    = TextEditingController();
  final _garage      = TextEditingController();
  String _type       = 'OIL_CHANGE';
  String _date       = DateTime.now().toIso8601String().substring(0, 10);
  String? _nextDue;
  bool _loading      = false;

  @override
  void dispose() {
    _desc.dispose(); _cost.dispose(); _odometer.dispose(); _garage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      await container.read(dioProvider).post('/vehicles/${widget.vehicleId}/maintenance-logs', data: {
        'type': _type,
        'date': _date,
        'description': _desc.text.trim(),
        if (_cost.text.trim().isNotEmpty) 'cost': int.parse(_cost.text.trim()),
        if (_odometer.text.trim().isNotEmpty) 'odometer': int.parse(_odometer.text.trim()),
        if (_garage.text.trim().isNotEmpty) 'garage': _garage.text.trim(),
        if (_nextDue != null) 'nextDueAt': _nextDue,
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Enregistrer un entretien',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: widget.typeLabel.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked.toIso8601String().substring(0, 10));
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
                      const Text('Date', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      Text(_date, style: const TextStyle(fontSize: 13)),
                    ]),
                  ]),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _cost,
                decoration: const InputDecoration(labelText: 'Coût', suffixText: 'F'),
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _odometer,
                decoration: const InputDecoration(labelText: 'Kilométrage', suffixText: 'km'),
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _garage,
                decoration: const InputDecoration(labelText: 'Garage'),
              )),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _nextDue = picked.toIso8601String().substring(0, 10));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.event_outlined, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Prochain entretien', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    Text(_nextDue ?? 'Non défini', style: const TextStyle(fontSize: 13)),
                  ]),
                ]),
              ),
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
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDate(String iso) {
  if (iso.length < 10) return iso;
  final parts = iso.substring(0, 10).split('-');
  if (parts.length < 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
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
