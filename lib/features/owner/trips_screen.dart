import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

final _ownerTripsProvider = FutureProvider.autoDispose.family<List<Trip>, String>((ref, date) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips', queryParameters: {'date': date, 'limit': 50});
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class OwnerTripsScreen extends ConsumerStatefulWidget {
  const OwnerTripsScreen({super.key});
  @override
  ConsumerState<OwnerTripsScreen> createState() => _State();
}

class _State extends ConsumerState<OwnerTripsScreen> {
  int _tab = 0; // 0=today 1=tomorrow 2=week

  String get _date {
    final now = DateTime.now();
    if (_tab == 0) return DateFormat('yyyy-MM-dd').format(now);
    if (_tab == 1) return DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
    return DateFormat('yyyy-MM-dd').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(_ownerTripsProvider(_date));

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des voyages')),
      body: Column(children: [
        // Tab bar
        Container(
          color: Colors.white,
          child: Row(children: [
            _Tab(label: "Aujourd'hui", index: 0, current: _tab, onTap: (i) => setState(() => _tab = i)),
            _Tab(label: 'Demain',       index: 1, current: _tab, onTap: (i) => setState(() => _tab = i)),
            _Tab(label: 'Cette semaine',index: 2, current: _tab, onTap: (i) => setState(() => _tab = i)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: tripsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (trips) => trips.isEmpty
              ? Center(child: Text('Aucun voyage', style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (_, i) => _TripRow(
                    trip: trips[i],
                    onStatusChange: (status) => _updateStatus(trips[i].id, status, ref),
                  ),
                ),
        )),
      ]),
    );
  }

  Future<void> _updateStatus(String tripId, String status, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/trips/$tripId/status', data: {'status': status});
      ref.invalidate(_ownerTripsProvider(_date));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  const _Tab({required this.label, required this.index, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(child: InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: sel ? brandOrange : Colors.transparent, width: 2,
          )),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(
            color: sel ? brandOrange : const Color(0xFF94A3B8),
            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          )),
      ),
    ));
  }
}

class _TripRow extends StatelessWidget {
  final Trip trip;
  final ValueChanged<String> onStatusChange;
  const _TripRow({required this.trip, required this.onStatusChange});

  static const _statusCfg = {
    'SCHEDULED': (Color(0xFFF1F5F9), Color(0xFF64748B), 'Planifié'),
    'BOARDING':  (Color(0xFFFEF9C3), Color(0xFFCA8A04), 'Embarquement'),
    'DEPARTED':  (Color(0xFFDCFCE7), Color(0xFF16A34A), 'Parti'),
    'ARRIVED':   (Color(0xFFF0F9FF), Color(0xFF0369A1), 'Arrivé'),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), 'Annulé'),
  };

  static const _transitions = {
    'SCHEDULED': ['BOARDING', 'CANCELLED'],
    'BOARDING':  ['DEPARTED', 'CANCELLED'],
    'DEPARTED':  ['ARRIVED'],
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _statusCfg[trip.status] ?? _statusCfg['SCHEDULED']!;
    final actions = _transitions[trip.status] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Text(DateFormat('HH:mm').format(trip.departureAt.toLocal()),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandOrange)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${trip.originCity} → ${trip.destinationCity}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: brandDark)),
              Text('${trip.tripClass} · ${trip.vehiclePlate ?? '—'}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
              child: Text(cfg.$3, style: TextStyle(color: cfg.$2, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions.map((s) {
              final c = _statusCfg[s]!;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.$2,
                    side: BorderSide(color: c.$2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => onStatusChange(s),
                  child: Text(c.$3),
                ),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }
}
