import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_bell.dart';

final _todayTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.read(authProvider).user!;
  final dio  = ref.read(dioProvider);
  final res  = await dio.get('/stations/${user.stationId}/trips/today');
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class DeparturesScreen extends ConsumerWidget {
  const DeparturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user       = ref.watch(authProvider).user!;
    final tripsAsync = ref.watch(_todayTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Départs du jour'),
          if (user.stationName != null)
            Text(user.stationName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8))),
        ]),
        actions: [
          const NotificationBell(notificationsRoute: '/agent/notifications'),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_todayTripsProvider),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (trips) {
          if (trips.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.departure_board_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Aucun départ aujourd\'hui', style: TextStyle(color: Colors.grey[400])),
          ]));
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_todayTripsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (_, i) => _DepartureCard(trip: trips[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Departure card ────────────────────────────────────────────────────────────

class _DepartureCard extends ConsumerStatefulWidget {
  final Trip trip;
  const _DepartureCard({required this.trip});
  @override
  ConsumerState<_DepartureCard> createState() => _DepartureCardState();
}

class _DepartureCardState extends ConsumerState<_DepartureCard> {
  // GPS sharing state — only relevant for DEPARTED trips.
  bool _sharing = false;
  double _speed = 0;
  StreamSubscription<Position>? _locationSub;
  io.Socket? _socket;

  static const _statusCfg = {
    'SCHEDULED': (Color(0xFFF1F5F9), Color(0xFF64748B), 'Planifié'),
    'BOARDING':  (Color(0xFFFEF9C3), Color(0xFFCA8A04), 'Embarquement'),
    'DEPARTED':  (Color(0xFFDCFCE7), Color(0xFF16A34A), 'Parti'),
    'ARRIVED':   (Color(0xFFF0F9FF), Color(0xFF0369A1), 'Arrivé'),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), 'Annulé'),
  };

  @override
  void dispose() {
    _stopSharing();
    super.dispose();
  }

  Future<void> _startSharing() async {
    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission de localisation refusée'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check GPS service
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activez le GPS dans les paramètres')),
        );
      }
      return;
    }

    // Open socket
    final token = ref.read(authProvider).accessToken;
    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth(token != null ? {'token': token} : <String, dynamic>{})
          .build(),
    );
    _socket!.connect();

    // Start GPS stream — emit every 15 metres moved
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      _socket?.emit('location:update', {
        'tripId':  widget.trip.id,
        'lat':     pos.latitude,
        'lng':     pos.longitude,
        'heading': pos.heading,
        'speed':   (pos.speed * 3.6).toStringAsFixed(1), // m/s → km/h
      });
      if (mounted) setState(() => _speed = pos.speed * 3.6);
    });

    if (mounted) setState(() => _sharing = true);
  }

  void _stopSharing() {
    _locationSub?.cancel();
    _locationSub = null;
    _socket?.emit('location:update', {
      'tripId': widget.trip.id,
      'lat': 0, 'lng': 0, // signal to stop (server can handle 0,0 as offline)
    });
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (mounted) setState(() { _sharing = false; _speed = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final cfg = _statusCfg[trip.status] ?? _statusCfg['SCHEDULED']!;
    final occupied = trip.totalSeats - trip.availableSeats;
    final pct = trip.totalSeats > 0 ? occupied / trip.totalSeats : 0.0;
    final isDeparted = trip.status == 'DEPARTED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${trip.originCity} → ${trip.destinationCity}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
              const SizedBox(height: 4),
              Text(DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: brandOrange)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
              child: Text(cfg.$3, style: TextStyle(color: cfg.$2, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$occupied',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
                Text('/${trip.totalSeats} passagers',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(pct > 0.8 ? Colors.red : brandOrange),
                  minHeight: 6,
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(trip.tripClass,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(trip.vehiclePlate ?? '—',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ]),
          ]),

          // ── Manifest button ───────────────────────────────────────────
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/agent/manifest/${trip.id}'),
              icon: const Icon(Icons.format_list_bulleted, size: 16),
              label: Text('Manifeste · $occupied passager${occupied != 1 ? 's' : ''}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandOrange,
                side: BorderSide(color: brandOrange.withValues(alpha: 0.31)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // ── GPS driver banner — only for DEPARTED trips ───────────────
          if (isDeparted) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _DriverGpsBanner(
              sharing: _sharing,
              speed: _speed,
              onStart: _startSharing,
              onStop: _stopSharing,
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Driver GPS banner ─────────────────────────────────────────────────────────

class _DriverGpsBanner extends StatelessWidget {
  final bool sharing;
  final double speed;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _DriverGpsBanner({
    required this.sharing, required this.speed,
    required this.onStart, required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (sharing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const _PulsingDot(color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Position partagée en direct',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF15803D))),
            if (speed > 0)
              Text('${speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12)),
          ])),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Arrêter', style: TextStyle(fontSize: 12)),
          ),
        ]),
      );
    }

    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: brandLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandOrange.withValues(alpha: 0.31)),
        ),
        child: Row(children: [
          const Icon(Icons.gps_fixed, color: brandOrange, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode conducteur',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark)),
            Text('Partagez votre position aux passagers',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ])),
          const Icon(Icons.chevron_right, color: brandOrange, size: 18),
        ]),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
    child: Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
