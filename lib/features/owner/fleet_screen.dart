import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final _vehiclesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/vehicles');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(_vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flotte')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (vehicles) => vehicles.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucun véhicule', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddVehicleSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un véhicule'),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                itemBuilder: (_, i) => _VehicleCard(
                  vehicle: vehicles[i],
                  onToggle: (id, active) => _toggleVehicle(id, active, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _toggleVehicle(String id, bool activate, WidgetRef ref, BuildContext context) async {
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
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
      builder: (_) => _AddVehicleSheet(onSaved: () {
        Navigator.pop(context);
        ref.invalidate(_vehiclesProvider);
      }),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final void Function(String id, bool activate) onToggle;
  const _VehicleCard({required this.vehicle, required this.onToggle});

  static const _statusCfg = {
    'ACTIVE':       (Color(0xFFDCFCE7), Color(0xFF16A34A), 'Actif'),
    'INACTIVE':     (Color(0xFFF1F5F9), Color(0xFF64748B), 'Inactif'),
    'MAINTENANCE':  (Color(0xFFFEF9C3), Color(0xFFCA8A04), 'Maintenance'),
    'OUT_OF_SERVICE':(Color(0xFFFEE2E2), Color(0xFFDC2626), 'Hors service'),
  };

  @override
  Widget build(BuildContext context) {
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
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: brandLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_bus_outlined, color: brandOrange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plate, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: brandDark)),
              Text('$brand $model', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
              child: Text(cfg.$3, style: TextStyle(color: cfg.$2, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _InfoChip(icon: Icons.event_seat_outlined, label: '$capacity places'),
            const SizedBox(width: 8),
            _InfoChip(icon: Icons.star_outline, label: tripClass),
            const Spacer(),
            TextButton(
              onPressed: () => onToggle(vehicle['id'], !isActive),
              style: TextButton.styleFrom(
                foregroundColor: isActive ? Colors.red : const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(isActive ? 'Désactiver' : 'Activer'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
  ]);
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
    _plate.dispose(); _brand.dispose(); _model.dispose(); _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final container = ProviderScope.containerOf(context);
      final dio = container.read(dioProvider);
      await dio.post('/vehicles', data: {
        'plate': _plate.text.trim().toUpperCase(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'capacity': int.parse(_capacity.text.trim()),
        'tripClass': _class,
      });
      widget.onSaved();
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nouveau véhicule',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _plate,
            decoration: const InputDecoration(labelText: 'Immatriculation'),
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Marque'),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Modèle'),
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _capacity,
              decoration: const InputDecoration(labelText: 'Capacité'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                if (int.tryParse(v) == null) return 'Nombre';
                return null;
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              value: _class,
              decoration: const InputDecoration(labelText: 'Classe'),
              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _class = v!),
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
