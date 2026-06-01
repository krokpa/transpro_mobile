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
import '../../l10n/app_localizations.dart';

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
  bool _disposed = false;

  LatLng? _busPosition;
  double _busHeading = 0;
  double _busSpeed = 0;

  late final MapController _mapController;
  bool _followBus = true; // false when user pans manually
  bool _userPanned = false;

  // Pulsing animation for the véhicule marker
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fetchInitial();
    _connectSocket();
  }

  Future<void> _fetchInitial() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips/${widget.tripId}');
      final data = extractData(res.data);
      if (mounted)
        setState(() {
          _trip = Trip.fromJson(data);
          _initialLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _initialLoading = false;
        });
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
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.connected);
      _socket!.emit('trip:join', {'tripId': widget.tripId});
    });

    _socket!.onDisconnect((_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.disconnected);
    });

    _socket!.on('reconnecting', (_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.reconnecting);
    });

    _socket!.on('reconnect', (_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.connected);
      _socket!.emit('trip:join', {'tripId': widget.tripId});
    });

    // Status change from owner/agent
    _socket!.on('trip:status_changed', (data) {
      if (_disposed || !mounted) return;
      try {
        final map = data as Map<String, dynamic>;
        final tripData = map['trip'] ?? map;
        setState(() => _trip = Trip.fromJson(extractData(tripData)));
      } catch (_) {}
    });

    // Real-time véhicule location from driver
    _socket!.on('bus:location', (data) {
      if (_disposed || !mounted) return;
      try {
        final map = data as Map<String, dynamic>;
        final lat = (map['lat'] as num?)?.toDouble();
        final lng = (map['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;

        final newPos = LatLng(lat, lng);
        setState(() {
          _busPosition = newPos;
          _busHeading = (map['heading'] as num?)?.toDouble() ?? _busHeading;
          _busSpeed = (map['speed'] as num?)?.toDouble() ?? _busSpeed;
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
    _disposed = true;
    _socket?.emit('trip:leave', {'tripId': widget.tripId});
    _socket?.disconnect();
    _socket?.dispose();
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    if (_busPosition == null) return;
    setState(() {
      _followBus = true;
      _userPanned = false;
    });
    _mapController.move(_busPosition!, 15);
  }

  void _share() {
    if (_trip == null) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final t = _trip!;
    final dep = DateFormat('HH:mm').format(t.departureAt.toLocal());
    final date = DateFormat(
      'd MMMM yyyy',
      locale,
    ).format(t.departureAt.toLocal());
    final statusLabel = _tripStatusLabel(t.status, l10n);
    Share.share(
      '🚌 ${l10n.tripTrackingTitle} — TransPro CI\n'
      '${t.originCity} → ${t.destinationCity}\n'
      '📅 $date · ${l10n.tripDeparture} $dep\n'
      '📍 ${l10n.status} : $statusLabel'
      '${t.vehiclePlate != null ? '\n🚌 ${t.vehiclePlate}' : ''}',
      subject:
          '${l10n.tripTrackingTitle} ${t.originCity} → ${t.destinationCity}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: context.cardBg.withAlpha(220),
        elevation: 0,
        title: _trip == null
            ? Text(l10n.tripTrackingTitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_trip!.originCity} → ${_trip!.destinationCity}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (_busSpeed > 0)
                    Text(
                      '${_busSpeed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
        actions: [
          if (_trip != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _share,
            ),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _trip == null
          ? _ErrorView(
              onRetry: () {
                setState(() {
                  _error = null;
                  _initialLoading = true;
                });
                _fetchInitial();
              },
            )
          : Stack(
              children: [
                // ── Full-screen map ───────────────────────────────────────
                _MapLayer(
                  mapController: _mapController,
                  busPosition: _busPosition,
                  busHeading: _busHeading,
                  pulseAnim: _pulseAnim,
                  trip: _trip,
                  onPositionChanged: (hasGesture) {
                    if (hasGesture && _busPosition != null) {
                      setState(() {
                        _followBus = false;
                        _userPanned = true;
                      });
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
                if (_busPosition == null &&
                    _trip != null &&
                    (_trip!.status == 'DEPARTED' ||
                        _trip!.status == 'BOARDING'))
                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                    left: 12,
                    right: 80,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardBg.withAlpha(230),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.tripTrackingWaiting,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Re-center FAB ─────────────────────────────────────────
                if (_userPanned && _busPosition != null)
                  Positioned(
                    bottom: 220,
                    right: 16,
                    child: Material(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _recenter,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.my_location, color: brandOrange, size: 22),
                        ),
                      ),
                    ),
                  ),

                // ── Bottom info sheet ─────────────────────────────────────
                if (_trip != null)
                  _BottomSheet(
                    trip: _trip!,
                    busSpeed: _busSpeed,
                    busPosition: _busPosition,
                  ),
              ],
            ),
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
        initialZoom: busPosition != null ? 15 : 9,
        onPositionChanged: (pos, hasGesture) => onPositionChanged(hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.transpro.mobile',
          maxZoom: 19,
        ),
        if (busPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: busPosition!,
                width: 56,
                height: 56,
                child: _BusMarker(heading: busHeading, pulseAnim: pulseAnim),
              ),
            ],
          ),
      ],
    );
  }
}

// Animated rotating véhicule marker
class _BusMarker extends AnimatedWidget {
  final double heading;
  const _BusMarker({
    required this.heading,
    required Animation<double> pulseAnim,
  }) : super(listenable: pulseAnim);

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
              BoxShadow(
                color: brandOrange.withAlpha(120),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Colors.white,
            size: 28,
          ),
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
    final l10n = AppLocalizations.of(context);
    final (Color bg, Color fg, String label) = switch (status) {
      _SocketStatus.connected => (
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
        l10n.tripSocketLive,
      ),
      _SocketStatus.connecting => (
        const Color(0xFFFEF9C3),
        const Color(0xFFCA8A04),
        l10n.tripSocketConnecting,
      ),
      _SocketStatus.reconnecting => (
        const Color(0xFFFEF9C3),
        const Color(0xFFCA8A04),
        l10n.tripSocketReconnecting,
      ),
      _SocketStatus.disconnected => (
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
        l10n.tripSocketOffline,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Bottom sheet with trip info ───────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final Trip trip;
  final double busSpeed;
  final LatLng? busPosition;
  const _BottomSheet({
    required this.trip,
    required this.busSpeed,
    required this.busPosition,
  });

  static const _steps = ['SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.12, 0.22, 0.65],
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status row ────────────────────────────────────────────
                  Row(
                    children: [
                      _StatusDot(status: trip.status),
                      const SizedBox(width: 8),
                      Text(
                        _tripStatusLabel(trip.status, l10n),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: context.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (trip.estimatedArrivalAt != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              l10n.tripTrackingEta,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textMuted,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(trip.estimatedArrivalAt!.toLocal()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: brandOrange,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // ── Route ─────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.originCity} → ${trip.destinationCity}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (busSpeed > 2)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.tagBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${busSpeed.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                color: brandOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // ── Mini timeline (scrolled section) ─────────────────────
                  const SizedBox(height: 8),
                  Text(
                    l10n.tripTrackingSteps,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MiniTimeline(
                    currentStatus: trip.status,
                    steps: _steps,
                    departureAt: trip.departureAt,
                    eta: trip.estimatedArrivalAt,
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Vehicle / Driver info ─────────────────────────────────
                  if (trip.vehiclePlate != null)
                    _InfoRow(
                      icon: Icons.directions_bus_outlined,
                      label: trip.vehiclePlate!,
                    ),
                  if (trip.driverName != null)
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: trip.driverName!,
                    ),
                  _InfoRow(
                    icon: Icons.event_seat_outlined,
                    label: l10n.tripTrackingOccupied(
                      trip.totalSeats - trip.availableSeats,
                      trip.totalSeats,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
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
    'BOARDING': Color(0xFFCA8A04),
    'DEPARTED': Color(0xFF16A34A),
    'ARRIVED': Color(0xFF0369A1),
    'CANCELLED': Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? const Color(0xFF64748B);
    return Container(
      width: 10,
      height: 10,
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
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
      ],
    ),
  );
}

// ── Compact horizontal timeline ───────────────────────────────────────────────

class _MiniTimeline extends StatelessWidget {
  final String currentStatus;
  final List<String> steps;
  final DateTime departureAt;
  final DateTime? eta;
  const _MiniTimeline({
    required this.currentStatus,
    required this.steps,
    required this.departureAt,
    required this.eta,
  });

  static const _times = {'DEPARTED': true, 'ARRIVED': true};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIdx = steps.indexOf(currentStatus);
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final step = e.value;
        final done = i < currentIdx;
        final active = i == currentIdx;
        final dotColor = done
            ? const Color(0xFF16A34A)
            : active
            ? brandOrange
            : context.divider;
        final timeLabel = _times[step] == true
            ? (step == 'DEPARTED'
                  ? DateFormat('HH:mm').format(departureAt.toLocal())
                  : eta != null
                  ? DateFormat('HH:mm').format(eta!.toLocal())
                  : null)
            : null;

        return Expanded(
          child: Column(
            children: [
              // Connector + dot row
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: done ? const Color(0xFF16A34A) : context.divider,
                      ),
                    ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 10)
                        : active
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: done ? const Color(0xFF16A34A) : context.divider,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _tripStatusLabel(step, l10n),
                style: TextStyle(
                  fontSize: 9,
                  color: active
                      ? brandOrange
                      : done
                      ? context.textSecondary
                      : context.divider,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (timeLabel != null)
                Text(
                  timeLabel,
                  style: TextStyle(fontSize: 9, color: context.textMuted),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_wifi_off_outlined,
            size: 56,
            color: context.textMuted,
          ),
          const SizedBox(height: 12),
          Text(l10n.error, style: TextStyle(color: context.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

String _tripStatusLabel(String s, AppLocalizations l10n) => switch (s) {
  'SCHEDULED' => l10n.tripStatusScheduled,
  'BOARDING' => l10n.tripStatusBoarding,
  'DEPARTED' => l10n.tripStatusDeparted,
  'ARRIVED' => l10n.tripStatusArrived,
  'CANCELLED' => l10n.tripStatusCancelled,
  _ => s,
};
