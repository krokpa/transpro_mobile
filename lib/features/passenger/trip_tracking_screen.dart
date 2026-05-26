import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

enum _SocketStatus { connecting, connected, reconnecting, disconnected }

// Default center: Abidjan
const _defaultCenter = LatLng(5.3600, -4.0083);

class TripTrackingScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends ConsumerState<TripTrackingScreen>
    with SingleTickerProviderStateMixin {
  Trip? _trip;
  bool _initialLoading = true;
  String? _error;

  io.Socket? _socket;
  _SocketStatus _socketStatus = _SocketStatus.connecting;

  LatLng? _busPosition;
  double _busHeading = 0;
  double _busSpeed   = 0;

  late final MapController _mapController;
  bool _followBus = true;           // false when user pans manually
  bool _userPanned = false;

  // Pulsing animation for the bus marker
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fetchInitial();
    _connectSocket();
  }

  Future<void> _fetchInitial() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips/${widget.tripId}');
      final data = extractData(res.data);
      if (mounted) setState(() { _trip = Trip.fromJson(data); _initialLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _initialLoading = false; });
    }
  }

  void _connectSocket() {
    final token = ref.read(authProvider).accessToken;

    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setTimeout(8000)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth(token != null ? {'token': token} : <String, dynamic>{})
          .build(),
    );

    _socket!.onConnect((_) {
      if (mounted) setState(() => _socketStatus = _SocketStatus.connected);
      _socket!.emit('trip:join', {'tripId': widget.tripId});
    });

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _socketStatus = _SocketStatus.disconnected);
    });

    _socket!.on('reconnecting', (_) {
      if (mounted) setState(() => _socketStatus = _SocketStatus.reconnecting);
    });

    _socket!.on('reconnect', (_) {
      if (mounted) {
        setState(() => _socketStatus = _SocketStatus.connected);
        _socket!.emit('trip:join', {'tripId': widget.tripId});
      }
    });

    // Status change from owner/agent
    _socket!.on('trip:status_changed', (data) {
      if (!mounted) return;
      try {
        final map = data as Map<String, dynamic>;
        final tripData = map['trip'] ?? map;
        setState(() => _trip = Trip.fromJson(extractData(tripData)));
      } catch (_) {}
    });

    // Real-time bus location from driver
    _socket!.on('bus:location', (data) {
      if (!mounted) return;
      try {
        final map = data as Map<String, dynamic>;
        final lat = (map['lat'] as num?)?.toDouble();
        final lng = (map['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;

        final newPos = LatLng(lat, lng);
        setState(() {
          _busPosition = newPos;
          _busHeading  = (map['heading'] as num?)?.toDouble() ?? _busHeading;
          _busSpeed    = (map['speed']   as num?)?.toDouble() ?? _busSpeed;
        });

        if (_followBus) {
          _mapController.move(newPos, math.max(_mapController.camera.zoom, 14));
        }
      } catch (_) {}
    });

    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.emit('trip:leave', {'tripId': widget.tripId});
    _socket?.disconnect();
    _socket?.dispose();
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    if (_busPosition == null) return;
    setState(() { _followBus = true; _userPanned = false; });
    _mapController.move(_busPosition!, 15);
  }

  void _share() {
    if (_trip == null) return;
    final t = _trip!;
    final dep = DateFormat('HH:mm').format(t.departureAt.toLocal());
    final date = DateFormat('d MMMM yyyy', 'fr_FR').format(t.departureAt.toLocal());
    Share.share(
      '🚌 Suivi en direct — TransPro CI\n'
      '${t.originCity} → ${t.destinationCity}\n'
      '📅 $date · Départ $dep\n'
      '📍 Statut : ${_statusLabel(t.status)}'
      '${t.vehiclePlate != null ? '\n🚌 ${t.vehiclePlate}' : ''}',
      subject: 'Suivi ${t.originCity} → ${t.destinationCity}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(220),
        elevation: 0,
        title: _trip == null
            ? const Text('Suivi en direct')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_trip!.originCity} → ${_trip!.destinationCity}',
                    style: const TextStyle(fontSize: 15)),
                if (_busSpeed > 0)
                  Text('${_busSpeed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400)),
              ]),
        actions: [
          if (_trip != null)
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: _share),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _trip == null
              ? _ErrorView(onRetry: () {
                  setState(() { _error = null; _initialLoading = true; });
                  _fetchInitial();
                })
              : Stack(children: [
                  // ── Full-screen map ───────────────────────────────────────
                  _MapLayer(
                    mapController: _mapController,
                    busPosition: _busPosition,
                    busHeading: _busHeading,
                    pulseAnim: _pulseAnim,
                    trip: _trip,
                    onPositionChanged: (hasGesture) {
                      if (hasGesture && _busPosition != null) {
                        setState(() { _followBus = false; _userPanned = true; });
                      }
                    },
                  ),

                  // ── Connection chip (top-right) ───────────────────────────
                  Positioned(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                    right: 12,
                    child: _ConnectionChip(status: _socketStatus),
                  ),

                  // ── No-location hint ─────────────────────────────────────
                  if (_busPosition == null && _trip != null &&
                      (_trip!.status == 'DEPARTED' || _trip!.status == 'BOARDING'))
                    Positioned(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                      left: 12,
                      right: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('En attente de localisation…',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ]),
                      ),
                    ),

                  // ── Re-center FAB ─────────────────────────────────────────
                  if (_userPanned && _busPosition != null)
                    Positioned(
                      bottom: 220,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter',
                        backgroundColor: Colors.white,
                        foregroundColor: brandOrange,
                        onPressed: _recenter,
                        child: const Icon(Icons.my_location),
                      ),
                    ),

                  // ── Bottom info sheet ─────────────────────────────────────
                  if (_trip != null)
                    _BottomSheet(trip: _trip!, busSpeed: _busSpeed, busPosition: _busPosition),
                ]),
    );
  }
}

// ── Map layer ─────────────────────────────────────────────────────────────────

class _MapLayer extends StatelessWidget {
  final MapController mapController;
  final LatLng? busPosition;
  final double busHeading;
  final Animation<double> pulseAnim;
  final Trip? trip;
  final void Function(bool hasGesture) onPositionChanged;

  const _MapLayer({
    required this.mapController,
    required this.busPosition,
    required this.busHeading,
    required this.pulseAnim,
    required this.trip,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: busPosition ?? _defaultCenter,
        initialZoom:   busPosition != null ? 15 : 9,
        onPositionChanged: (pos, hasGesture) => onPositionChanged(hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.transpro.mobile',
          maxZoom: 19,
        ),
        if (busPosition != null)
          MarkerLayer(markers: [
            Marker(
              point: busPosition!,
              width: 56,
              height: 56,
              child: _BusMarker(heading: busHeading, pulseAnim: pulseAnim),
            ),
          ]),
      ],
    );
  }
}

// Animated rotating bus marker
class _BusMarker extends AnimatedWidget {
  final double heading;
  const _BusMarker({required this.heading, required Animation<double> pulseAnim})
      : super(listenable: pulseAnim);

  @override
  Widget build(BuildContext context) {
    final scale = (listenable as Animation<double>).value;
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: heading * math.pi / 180,
        child: Container(
          decoration: BoxDecoration(
            color: brandOrange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: brandOrange.withAlpha(120), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── Connection status chip ────────────────────────────────────────────────────

class _ConnectionChip extends StatelessWidget {
  final _SocketStatus status;
  const _ConnectionChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      _SocketStatus.connected    => (const Color(0xFFDCFCE7), const Color(0xFF16A34A), '● En direct'),
      _SocketStatus.connecting   => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04), '○ Connexion…'),
      _SocketStatus.reconnecting => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04), '○ Reconnexion…'),
      _SocketStatus.disconnected => (const Color(0xFFFEE2E2), const Color(0xFFDC2626), '✕ Hors ligne'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6)],
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Bottom sheet with trip info ───────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final Trip trip;
  final double busSpeed;
  final LatLng? busPosition;
  const _BottomSheet({required this.trip, required this.busSpeed, required this.busPosition});

  static const _steps = ['SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED'];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.12, 0.22, 0.65],
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            // Drag handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            )),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Status row ────────────────────────────────────────────
                Row(children: [
                  _StatusDot(status: trip.status),
                  const SizedBox(width: 8),
                  Text(_statusLabel(trip.status),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: brandDark)),
                  const Spacer(),
                  if (trip.estimatedArrivalAt != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Arrivée prévue',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(DateFormat('HH:mm').format(trip.estimatedArrivalAt!.toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandOrange)),
                    ]),
                ]),

                // ── Route ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text('${trip.originCity} → ${trip.destinationCity}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const Spacer(),
                    if (busSpeed > 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandLight, borderRadius: BorderRadius.circular(20)),
                        child: Text('${busSpeed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(color: brandOrange, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),

                const Divider(),

                // ── Mini timeline (scrolled section) ─────────────────────
                const SizedBox(height: 8),
                const Text('Étapes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
                      color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                _MiniTimeline(currentStatus: trip.status, steps: _steps,
                    departureAt: trip.departureAt, eta: trip.estimatedArrivalAt),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                // ── Vehicle / Driver info ─────────────────────────────────
                if (trip.vehiclePlate != null)
                  _InfoRow(icon: Icons.directions_bus_outlined, label: trip.vehiclePlate!),
                if (trip.driverName != null)
                  _InfoRow(icon: Icons.person_outline, label: trip.driverName!),
                _InfoRow(icon: Icons.event_seat_outlined,
                    label: '${trip.totalSeats - trip.availableSeats}/${trip.totalSeats} sièges occupés'),
                const SizedBox(height: 20),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  static const _colors = {
    'SCHEDULED': Color(0xFF64748B),
    'BOARDING':  Color(0xFFCA8A04),
    'DEPARTED':  Color(0xFF16A34A),
    'ARRIVED':   Color(0xFF0369A1),
    'CANCELLED': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? const Color(0xFF64748B);
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
    ]),
  );
}

// ── Compact horizontal timeline ───────────────────────────────────────────────

class _MiniTimeline extends StatelessWidget {
  final String currentStatus;
  final List<String> steps;
  final DateTime departureAt;
  final DateTime? eta;
  const _MiniTimeline({
    required this.currentStatus, required this.steps,
    required this.departureAt,  required this.eta,
  });

  static const _labels = {
    'SCHEDULED': 'Planifié', 'BOARDING': 'Embarquement',
    'DEPARTED':  'En route', 'ARRIVED':  'Arrivé',
  };
  static const _times = {
    'DEPARTED': true, 'ARRIVED': true,
  };

  @override
  Widget build(BuildContext context) {
    final currentIdx = steps.indexOf(currentStatus);
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key; final step = e.value;
        final done   = i < currentIdx;
        final active = i == currentIdx;
        final dotColor = done   ? const Color(0xFF16A34A)
                       : active ? brandOrange
                                : const Color(0xFFE2E8F0);
        final timeLabel = _times[step] == true
            ? (step == 'DEPARTED'
                ? DateFormat('HH:mm').format(departureAt.toLocal())
                : eta != null ? DateFormat('HH:mm').format(eta!.toLocal()) : null)
            : null;

        return Expanded(child: Column(children: [
          // Connector + dot row
          Row(children: [
            if (i > 0)
              Expanded(child: Container(
                height: 2,
                color: done ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
              )),
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: done ? const Icon(Icons.check, color: Colors.white, size: 10)
                         : active ? Container(width: 6, height: 6,
                             decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                         : null,
            ),
            if (i < steps.length - 1)
              Expanded(child: Container(
                height: 2,
                color: done ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
              )),
          ]),
          const SizedBox(height: 4),
          Text(_labels[step] ?? step,
            style: TextStyle(
              fontSize: 9,
              color: active ? brandOrange : done ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
          if (timeLabel != null)
            Text(timeLabel,
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
        ]));
      }).toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.signal_wifi_off_outlined, size: 56, color: Colors.grey[300]),
    const SizedBox(height: 12),
    Text('Impossible de charger le voyage', style: TextStyle(color: Colors.grey[500])),
    const SizedBox(height: 8),
    TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
  ]));
}

String _statusLabel(String s) => const {
  'SCHEDULED': 'Planifié', 'BOARDING': 'Embarquement',
  'DEPARTED':  'En route', 'ARRIVED':  'Arrivé', 'CANCELLED': 'Annulé',
}[s] ?? s;
