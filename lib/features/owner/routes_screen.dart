import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/shimmer.dart';

final _routesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/routes');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

final _citiesForRoutesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cities');
  final items = extractData(res.data);
  return (items as List).map((e) => City.fromJson(e)).toList();
});

class OwnerRoutesScreen extends ConsumerWidget {
  const OwnerRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(_routesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text('Réseau',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              tooltip: 'Ajouter un itinéraire',
              onPressed: () => _showAddRouteSheet(context, ref),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (routes) => routes.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.alt_route, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucun itinéraire', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddRouteSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un itinéraire'),
                  ),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: routes.length,
                itemBuilder: (_, i) => _RouteCard(
                  route: routes[i],
                  onToggle: (id, active) => _toggleRoute(id, active, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _toggleRoute(String id, bool activate, WidgetRef ref, BuildContext context) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/routes/$id', data: {'isActive': activate});
      ref.invalidate(_routesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddRouteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddRouteSheet(onSaved: () {
        Navigator.pop(context);
        ref.invalidate(_routesProvider);
      }),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final void Function(String id, bool activate) onToggle;
  const _RouteCard({required this.route, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = route['isActive'] as bool? ?? true;
    final name = route['name'] as String? ?? '—';
    final origin = route['originCity']?['name'] as String? ?? '—';
    final dest = route['destinationCity']?['name'] as String? ?? '—';
    final distance = route['distanceKm'] as num?;
    final duration = route['durationMinutes'] as num?;
    final schedules = (route['schedules'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive ? brandLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.alt_route,
                color: isActive ? brandOrange : const Color(0xFF94A3B8), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
              Text('$origin → $dest', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  fontSize: 11, fontWeight: FontWeight.w600,
                )),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (distance != null) ...[
              _InfoChip(icon: Icons.straighten, label: '${distance.toInt()} km'),
              const SizedBox(width: 8),
            ],
            if (duration != null) ...[
              _InfoChip(icon: Icons.access_time, label: _fmtDuration(duration.toInt())),
              const SizedBox(width: 8),
            ],
            _InfoChip(icon: Icons.schedule, label: '$schedules horaires'),
            const Spacer(),
            TextButton(
              onPressed: () => onToggle(route['id'], !isActive),
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

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
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

class _AddRouteSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddRouteSheet({required this.onSaved});
  @override
  ConsumerState<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends ConsumerState<_AddRouteSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _distance = TextEditingController();
  final _duration = TextEditingController();
  final _basePrice = TextEditingController();
  City? _origin;
  City? _dest;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose(); _distance.dispose(); _duration.dispose(); _basePrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_origin == null || _dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez les villes'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/routes', data: {
        'name': _name.text.trim(),
        'originCityId': _origin!.id,
        'destinationCityId': _dest!.id,
        if (_distance.text.isNotEmpty) 'distanceKm': double.parse(_distance.text),
        if (_duration.text.isNotEmpty) 'durationMinutes': int.parse(_duration.text),
        if (_basePrice.text.isNotEmpty) 'basePrice': double.parse(_basePrice.text),
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
    final citiesAsync = ref.watch(_citiesForRoutesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nouvel itinéraire',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom de l\'itinéraire'),
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          citiesAsync.when(
            loading: () => Shimmer(child: Column(children: List.generate(2, (_) => const ShimmerListTile()))),
            error: (e, _) => Text('Erreur villes: $e'),
            data: (cities) => Row(children: [
              Expanded(child: SearchableDropdownField<City>(
                label:     'Ville départ',
                hint:      'Départ',
                value:     _origin,
                items:     cities,
                itemLabel: (c) => c.name,
                itemKey:   (c) => c.id,
                onChanged: (v) => setState(() => _origin = v),
                validator: (v) => v == null ? 'Requis' : null,
              )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Color(0xFF94A3B8)),
              ),
              Expanded(child: SearchableDropdownField<City>(
                label:     'Ville arrivée',
                hint:      'Arrivée',
                value:     _dest,
                items:     cities,
                itemLabel: (c) => c.name,
                itemKey:   (c) => c.id,
                onChanged: (v) => setState(() => _dest = v),
                validator: (v) => v == null ? 'Requis' : null,
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _distance,
              decoration: const InputDecoration(labelText: 'Distance (km)', hintText: 'Optionnel'),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Durée (min)', hintText: 'Optionnel'),
              keyboardType: TextInputType.number,
            )),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _basePrice,
            decoration: const InputDecoration(labelText: 'Prix de base (F CFA)', hintText: 'Optionnel'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer'),
            ),
          ),
        ]),
      ),
    );
  }
}
