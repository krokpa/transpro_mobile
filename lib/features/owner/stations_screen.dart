import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/shimmer.dart';

final _stationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/stations');
  final items = extractData(res.data);
  return (items as List).cast<Map<String, dynamic>>();
});

final _citiesForStationsProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/cities');
  final items = extractData(res.data);
  return (items as List).map((e) => City.fromJson(e)).toList();
});

class StationsScreen extends ConsumerWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_stationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text('Gares',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: brandDark),
            onPressed: () => ref.invalidate(_stationsProvider),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 20),
              tooltip: 'Ajouter une gare',
              onPressed: () => _showAddSheet(context, ref),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (stations) => stations.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucune gare', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Ajouter une gare'),
                ),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: stations.length,
                itemBuilder: (_, i) => _StationCard(
                  station: stations[i],
                  onSetPrimary: (id) => _setPrimary(id, ref, context),
                  onDelete: (id) => _delete(id, ref, context),
                ),
              ),
      ),
    );
  }

  Future<void> _setPrimary(String id, WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(dioProvider).patch('/stations/$id', data: {'isPrimary': true});
      ref.invalidate(_stationsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(String id, WidgetRef ref, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la gare'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(dioProvider).delete('/stations/$id');
      ref.invalidate(_stationsProvider);
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
      builder: (_) => _AddStationSheet(ref: ref),
    );
  }
}

// ── Station card ──────────────────────────────────────────────────────────────

class _StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final void Function(String) onSetPrimary;
  final void Function(String) onDelete;
  const _StationCard({required this.station, required this.onSetPrimary, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final id        = station['id'] as String;
    final name      = station['name'] as String? ?? '—';
    final address   = station['address'] as String? ?? '';
    final isPrimary = (station['isPrimary'] as bool?) ?? false;
    final cityName  = station['city']?['name'] as String?
        ?? station['cityName'] as String? ?? '';
    final agentCount = (station['_count']?['userStations'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isPrimary ? brandLight : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.store_outlined,
                color: isPrimary ? brandOrange : Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark))),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(8)),
                    child: Text('Principale',
                      style: TextStyle(color: brandOrange, fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
              ]),
              const SizedBox(height: 2),
              if (cityName.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_city_outlined, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text(cityName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  if (address.isNotEmpty) ...[
                    const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                    Expanded(child: Text(address,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              if (agentCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    const Icon(Icons.group_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text('$agentCount agent${agentCount > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ]),
                ),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (!isPrimary)
              Expanded(child: OutlinedButton.icon(
                onPressed: () => onSetPrimary(id),
                icon: const Icon(Icons.star_outline, size: 15),
                label: const Text('Définir principale', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandOrange,
                  side: BorderSide(color: brandOrange.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ))
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isPrimary ? null : () => onDelete(id),
              icon: Icon(
                Icons.delete_outline,
                color: isPrimary ? Colors.grey[300] : const Color(0xFFDC2626),
                size: 20,
              ),
              tooltip: isPrimary ? 'La gare principale ne peut pas être supprimée' : 'Supprimer',
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Add station sheet ─────────────────────────────────────────────────────────

class _AddStationSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddStationSheet({required this.ref});
  @override
  ConsumerState<_AddStationSheet> createState() => _AddStationSheetState();
}

class _AddStationSheetState extends ConsumerState<_AddStationSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _name     = TextEditingController();
  final _address  = TextEditingController();
  String? _cityId;
  bool _isPrimary = false;
  bool _loading   = false;

  @override
  void dispose() { _name.dispose(); _address.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _cityId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/stations', data: {
        'name':      _name.text.trim(),
        'cityId':    _cityId,
        'address':   _address.text.trim(),
        'isPrimary': _isPrimary,
      });
      ref.invalidate(_stationsProvider);
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
    final citiesAsync = ref.watch(_citiesForStationsProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SheetHandle(),
            const Text('Nouvelle gare',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom de la gare'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 14),
            citiesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
              data: (cities) => SearchableDropdownField<City>(
                label:     'Ville',
                hint:      'Sélectionner une ville…',
                value:     cities.cast<City?>().firstWhere(
                  (c) => c?.id == _cityId, orElse: () => null),
                items:     cities,
                itemLabel: (c) => c.name,
                itemKey:   (c) => c.id,
                onChanged: (c) => setState(() => _cityId = c?.id),
                validator: (v) => v == null ? 'Sélectionnez une ville' : null,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Adresse (optionnel)'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Gare principale', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Gare par défaut pour votre compte',
                style: TextStyle(fontSize: 12)),
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              activeThumbColor: brandOrange,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer la gare'),
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
