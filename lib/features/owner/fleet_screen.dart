import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/view_toggle_button.dart';
import '../../l10n/app_localizations.dart';

final _vehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/vehicles');
      final items = extractData(res.data);
      return (items as List).cast<Map<String, dynamic>>();
    });

class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key});
  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen> {
  bool _isGrid = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(_vehiclesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(l10n.fleetTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        actions: [
          ViewToggleButton(
            isGrid: _isGrid,
            onToggle: (v) => setState(() => _isGrid = v),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              tooltip: l10n.fleetAddVehicle,
              onPressed: () => _showAddVehicleSheet(context),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (vehicles) => vehicles.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined, size: 64, color: context.textMuted),
                  const SizedBox(height: 12),
                  Text(l10n.fleetNoVehicles, style: TextStyle(color: context.textMuted, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddVehicleSheet(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.fleetAddVehicle),
                  ),
                ]),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isGrid
                    ? GridView.builder(
                        key: const ValueKey('grid'),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: vehicles.length,
                        itemBuilder: (_, i) => _VehicleGridCard(
                          vehicle: vehicles[i],
                          onToggle: (id, active) => _toggleVehicle(id, active),
                          onDetail: (id) => context.push('/owner/fleet/$id'),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('list'),
                        padding: const EdgeInsets.all(16),
                        itemCount: vehicles.length,
                        itemBuilder: (_, i) => _VehicleCard(
                          vehicle: vehicles[i],
                          onToggle: (id, active) => _toggleVehicle(id, active),
                          onDetail: (id) => context.push('/owner/fleet/$id'),
                        ),
                      ),
              ),
      ),
    );
  }

  Future<void> _toggleVehicle(String id, bool activate) async {
    try {
      final dio = ref.read(dioProvider);
      if (activate) {
        await dio.patch('/vehicles/$id', data: {'status': 'ACTIVE'});
      } else {
        await dio.delete('/vehicles/$id');
      }
      ref.invalidate(_vehiclesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddVehicleSheet(BuildContext context) {
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

// ── Vehicle grid card ──────────────────────────────────────────────────────────

class _VehicleGridCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final void Function(String, bool) onToggle;
  final void Function(String) onDetail;
  const _VehicleGridCard({required this.vehicle, required this.onToggle, required this.onDetail});

  static const _statusCfg = {
    'ACTIVE':       (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'INACTIVE':     (Color(0xFFF1F5F9), Color(0xFF64748B)),
    'MAINTENANCE':  (Color(0xFFFEF9C3), Color(0xFFCA8A04)),
    'OUT_OF_SERVICE': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final status   = vehicle['status'] as String? ?? 'ACTIVE';
    final cfg      = _statusCfg[status] ?? _statusCfg['ACTIVE']!;
    final plate    = vehicle['plate']    as String? ?? '—';
    final brand    = vehicle['brand']    as String? ?? '';
    final model    = vehicle['model']    as String? ?? '—';
    final capacity = vehicle['capacity'] as int?    ?? 0;
    final id       = vehicle['id']       as String;
    final isActive = status == 'ACTIVE';

    return GestureDetector(
      onTap: () => onDetail(id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon + status badge
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_bus_outlined, color: brandOrange, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: cfg.$2),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Plate
            Text(plate, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: brandDark)),
            const SizedBox(height: 2),
            Text('$brand $model',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.event_seat_outlined, size: 12, color: context.textMuted),
              const SizedBox(width: 3),
              Text('$capacity pl.', style: TextStyle(fontSize: 11, color: context.textMuted)),
            ]),
            const Spacer(),
            // Toggle
            GestureDetector(
              onTap: () => onToggle(id, !isActive),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Désactiver' : 'Activer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
    'ACTIVE'       => 'Actif',
    'INACTIVE'     => 'Inactif',
    'MAINTENANCE'  => 'Maintenance',
    _              => s,
  };
}

// ── Vehicle list card (unchanged) ─────────────────────────────────────────────

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    initialValue: _class,
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
