import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

final _vehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/vehicles');
      final items = extractData(res.data);
      return (items as List).cast<Map<String, dynamic>>();
    });

class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(_vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fleetTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.fleetAddVehicle,
            onPressed: () => _showAddVehicleSheet(context, ref),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (vehicles) => vehicles.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_bus_outlined,
                      size: 64,
                      color: context.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.fleetNoVehicles,
                      style: TextStyle(color: context.textMuted, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _showAddVehicleSheet(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.fleetAddVehicle),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                itemBuilder: (_, i) => _VehicleCard(
                  vehicle: vehicles[i],
                  onToggle: (id, active) =>
                      _toggleVehicle(id, active, ref, context),
                  onDetail: (id) => context.push('/owner/fleet/$id'),
                ),
              ),
      ),
    );
  }

  Future<void> _toggleVehicle(
    String id,
    bool activate,
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      if (activate) {
        await dio.patch('/vehicles/$id', data: {'status': 'ACTIVE'});
      } else {
        await dio.delete('/vehicles/$id');
      }
      ref.invalidate(_vehiclesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddVehicleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddVehicleSheet(
        onSaved: () {
          Navigator.pop(context);
          ref.invalidate(_vehiclesProvider);
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final void Function(String id, bool activate) onToggle;
  final void Function(String id) onDetail;
  const _VehicleCard({
    required this.vehicle,
    required this.onToggle,
    required this.onDetail,
  });

  static const _statusCfg = {
    'ACTIVE': (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'INACTIVE': (Color(0xFFF1F5F9), Color(0xFF64748B)),
    'MAINTENANCE': (Color(0xFFFEF9C3), Color(0xFFCA8A04)),
    'OUT_OF_SERVICE': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = vehicle['status'] as String? ?? 'ACTIVE';
    final cfg = _statusCfg[status] ?? _statusCfg['ACTIVE']!;
    final plate = vehicle['plate'] as String? ?? '—';
    final model = vehicle['model'] as String? ?? '—';
    final brand = vehicle['brand'] as String? ?? '';
    final capacity = vehicle['capacity'] as int? ?? 0;
    final tripClass = vehicle['tripClass'] as String? ?? '—';
    final isActive = status == 'ACTIVE';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.tagBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_outlined,
                    color: brandOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '$brand $model',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.$1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _vehicleStatusLabel(status, l10n),
                    style: TextStyle(
                      color: cfg.$2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.event_seat_outlined,
                  label: l10n.stationSeats(capacity),
                ),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.star_outline, label: tripClass),
                const Spacer(),
                TextButton(
                  onPressed: () => onDetail(vehicle['id'] as String),
                  style: TextButton.styleFrom(
                    foregroundColor: brandOrange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(l10n.fleetMaintenanceTab),
                ),
                TextButton(
                  onPressed: () => onToggle(vehicle['id'], !isActive),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive
                        ? Colors.red
                        : const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(
                    isActive ? l10n.fleetDeactivate : l10n.fleetActivate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: context.textMuted),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: context.textMuted, fontSize: 12)),
    ],
  );
}

class _AddVehicleSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddVehicleSheet({required this.onSaved});
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _form = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _capacity = TextEditingController(text: '50');
  String _class = 'STANDARD';
  bool _loading = false;

  static const _classes = ['STANDARD', 'BUSINESS', 'VIP'];

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      final dio = container.read(dioProvider);
      await dio.post(
        '/vehicles',
        data: {
          'plate': _plate.text.trim().toUpperCase(),
          'brand': _brand.text.trim(),
          'model': _model.text.trim(),
          'capacity': int.parse(_capacity.text.trim()),
          'tripClass': _class,
        },
      );
      widget.onSaved();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.fleetNewVehicle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _plate,
              decoration: InputDecoration(labelText: l10n.fleetPlate),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => v == null || v.isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brand,
                    decoration: InputDecoration(labelText: l10n.fleetBrand),
                    validator: (v) =>
                        v == null || v.isEmpty ? l10n.required : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _model,
                    decoration: InputDecoration(labelText: l10n.fleetModel),
                    validator: (v) =>
                        v == null || v.isEmpty ? l10n.required : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    decoration: InputDecoration(labelText: l10n.fleetCapacity),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.required;
                      if (int.tryParse(v) == null) return l10n.invalidNumber;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _class,
                    decoration: InputDecoration(labelText: l10n.fleetClass),
                    items: _classes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _class = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _vehicleStatusLabel(String s, AppLocalizations l10n) => switch (s) {
  'ACTIVE' => l10n.fleetStatusActive,
  'INACTIVE' => l10n.fleetStatusInactive,
  'MAINTENANCE' => l10n.fleetStatusMaintenance,
  'OUT_OF_SERVICE' => l10n.fleetStatusOutOfService,
  _ => s,
};
