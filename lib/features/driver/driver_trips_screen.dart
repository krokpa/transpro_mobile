import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';
import 'location_sharing_widget.dart';

final _driverScheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, month) async {
  final res = await ref.read(dioProvider).get('/driver-space/schedule', queryParameters: {'month': month});
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

class DriverTripsScreen extends ConsumerStatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  ConsumerState<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends ConsumerState<DriverTripsScreen> {
  late String _month;

  static const _statusCfg = {
    'SCHEDULED': (Color(0xFFEFF6FF), Color(0xFF2563EB), 'Planifié'),
    'BOARDING':  (Color(0xFFFFFBEB), Color(0xFFD97706), 'Embarquement'),
    'DEPARTED':  (Color(0xFFF0FDF4), Color(0xFF16A34A), 'En route'),
    'ARRIVED':   (Color(0xFFF8FAFC), Color(0xFF64748B), 'Arrivé'),
    'CANCELLED': (Color(0xFFFEF2F2), Color(0xFFDC2626), 'Annulé'),
    'DELAYED':   (Color(0xFFFFF7ED), Color(0xFFEA580C), 'Retardé'),
  };

  static const _nextStatus = {
    'SCHEDULED': ['BOARDING'],
    'BOARDING':  ['DEPARTED'],
    'DELAYED':   ['BOARDING', 'DEPARTED'],
    'DEPARTED':  ['ARRIVED'],
  };

  static const _actionLabel = {
    'BOARDING': 'Embarquement',
    'DEPARTED': 'Parti',
    'ARRIVED':  'Arrivé',
  };

  static const _months = ['', 'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String get _monthLabel {
    final parts = _month.split('-');
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m < _months.length ? _months[m] : m} ${parts[0]}';
  }

  void _prevMonth() {
    setState(() {
      final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
      final p = DateTime(d.year, d.month - 1);
      _month = '${p.year}-${p.month.toString().padLeft(2, '0')}';
    });
  }

  void _nextMonth() {
    setState(() {
      final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
      final n = DateTime(d.year, d.month + 1);
      _month = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _updateStatus(String tripId, String status) async {
    try {
      await ref.read(dioProvider).patch('/driver-space/trips/$tripId/status', data: {'status': status});
      ref.invalidate(_driverScheduleProvider(_month));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Statut mis à jour'), backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_driverScheduleProvider(_month));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Mes voyages', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _prevMonth,
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8FAFC)),
              ),
              const SizedBox(width: 8),
              Text(_monthLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _nextMonth,
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8FAFC)),
              ),
            ]),
          ),
        ),
      ),
      body: Column(
        children: [
          const LocationSharingBanner(),
          Expanded(child: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (trips) {
          if (trips.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Aucun voyage en $_monthLabel', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
          ]));

          // Group by day
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final t in trips) {
            final dept = t['departureAt'] as String? ?? '';
            try {
              final dt = DateTime.parse(dept).toLocal();
              final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
              groups.putIfAbsent(key, () => []).add(t);
            } catch (_) {}
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final day = groups.keys.elementAt(i);
              final dayTrips = groups[day]!;
              final dt = DateTime.parse('$day 00:00:00');
              const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
              const ms = ['', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
              final dayLabel = '${days[dt.weekday]} ${dt.day} ${ms[dt.month]}';

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 10, top: i > 0 ? 16 : 0),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(8)),
                      child: Text(dayLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Container(height: 1, color: const Color(0xFFF1F5F9))),
                  ]),
                ),
                ...dayTrips.map((trip) {
                  final status  = trip['status'] as String? ?? 'SCHEDULED';
                  final cfg     = _statusCfg[status] ?? _statusCfg['SCHEDULED']!;
                  final dept    = trip['departureAt'] as String? ?? '';
                  final route   = trip['route'] as Map<String, dynamic>?;
                  final vehicle = trip['vehicle'] as Map<String, dynamic>?;
                  final next    = List<String>.from(_nextStatus[status] ?? []);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_fmtTime(dept), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brandOrange)),
                            Text('départ', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ]),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (route != null)
                              Text('${route['originCity']?['name']} → ${route['destinationCity']?['name']}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Row(children: [
                              if (vehicle != null) ...[
                                const Icon(Icons.directions_bus_outlined, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 3),
                                Text(vehicle['licensePlate'] as String? ?? '',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
                                const SizedBox(width: 8),
                              ],
                            ]),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(8)),
                              child: Text(cfg.$3, style: TextStyle(fontSize: 11, color: cfg.$2, fontWeight: FontWeight.w600)),
                            ),
                          ])),
                        ]),
                      ),
                      // Bouton GPS
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: LocationSharingButton(
                          tripId: trip['id'] as String,
                          tripStatus: status,
                        ),
                      ),

                      if (next.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(children: next.map((n) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: FilledButton(
                                onPressed: () => _updateStatus(trip['id'] as String, n),
                                style: FilledButton.styleFrom(
                                  backgroundColor: brandOrange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: Text(_actionLabel[n] ?? n,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          )).toList()),
                        ),
                    ]),
                  );
                }),
              ]);
            },
          );
        },
      )),
        ],
      ),
    );
  }

  String _fmtTime(String? d) {
    if (d == null || d.isEmpty) return '—';
    try { final dt = DateTime.parse(d).toLocal(); return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'; }
    catch (_) { return '—'; }
  }
}
