import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart' show Dio;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/map_config.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Trip? _trip;
  bool _initialLoading = true;
  String? _error;

  io.Socket? _socket;
  _SocketStatus _socketStatus = _SocketStatus.connecting;
  bool _disposed = false;

  LatLng? _busPosition;
  double _busHeading = 0;
  double _busSpeed = 0;

  List<LatLng> _routePoints = [];
  double _mapBearing = 0; // bearing arrivée→départ = direction "haut" de la carte

  late final MapController _mapController;
  bool _followBus = true; // false when user pans manually
  bool _userPanned = false;

  // Pulsing animation for the véhicule marker
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  // Reconnexion automatique quand l'app revient au premier plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !mounted) return;
    if (state == AppLifecycleState.resumed &&
        _socketStatus != _SocketStatus.connected) {
      setState(() => _socketStatus = _SocketStatus.reconnecting);
      _socket?.connect();
    }
  }

  Future<void> _fetchInitial() async {
    try {
      final dio = ref.read(dioProvider);

      // Les deux requêtes partent en parallèle
      final tripFuture = dio.get('/trips/${widget.tripId}');
      final locFuture  = dio.get('/trips/${widget.tripId}/location');

      final trip = Trip.fromJson(extractData((await tripFuture).data));
      if (!mounted) return;

      setState(() {
        _trip = trip;
        _initialLoading = false;
      });

      // Dernière position persistée (non bloquant — échec silencieux)
      _applyLastKnownPosition(locFuture);

      final depLat = trip.departureStationLat;
      final depLng = trip.departureStationLng;
      final arrLat = trip.arrivalStationLat;
      final arrLng = trip.arrivalStationLng;
      debugPrint('[Route] coords gares — dep: $depLat,$depLng  arr: $arrLat,$arrLng');
      if (depLat != null && depLng != null && arrLat != null && arrLng != null) {
        final dep = LatLng(depLat, depLng);
        final arr = LatLng(arrLat, arrLng);
        setState(() => _mapBearing = _bearingBetween(arr, dep));
        _fetchRoute(dep, arr);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _initialLoading = false;
        });
    }
  }

  Future<void> _applyLastKnownPosition(Future<dynamic> locFuture) async {
    try {
      final res = await locFuture;
      if (!mounted) return;
      final loc = extractData(res.data) as Map<String, dynamic>;
      if (loc['hasLocation'] != true) return;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _busPosition = LatLng(lat, lng);
        _busHeading  = (loc['heading'] as num?)?.toDouble() ?? 0;
        _busSpeed    = (loc['speed']   as num?)?.toDouble() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _fetchRoute(LatLng dep, LatLng arr) async {
    try {
      debugPrint('[Route] dep=${dep.latitude},${dep.longitude}  arr=${arr.latitude},${arr.longitude}');
      final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${dep.longitude},${dep.latitude};${arr.longitude},${arr.latitude}'
          '?geometries=geojson&overview=full&access_token=$kMapboxToken';
      final res = await Dio().get<Map<String, dynamic>>(url);
      final routes = res.data?['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('[Route] Mapbox: aucune route retournée — réponse: ${res.data}');
        return;
      }
      final coords = routes[0]['geometry']['coordinates'] as List;
      final points = coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      debugPrint('[Route] ${points.length} points reçus');
      if (!mounted || points.isEmpty) return;
      setState(() => _routePoints = points);
      // Toujours cadrer sur la route au premier chargement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.rotate(_mapBearing);
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
          ),
        );
      });
    } catch (e) {
      debugPrint('[Route] ERREUR: $e');
    }
  }

  // Bearing en degrés (0–360) de [from] vers [to]
  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
               math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _connectSocket() {
    final token = ref.read(authProvider).accessToken;

    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
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

    // Échec de connexion initiale (serveur inaccessible, token invalide…)
    _socket!.onConnectError((_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.disconnected);
    });

    // Chaque tentative de reconnexion automatique
    _socket!.onReconnectAttempt((_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.reconnecting);
    });

    // Reconnexion réussie → re-rejoindre la room du voyage
    _socket!.onReconnect((_) {
      if (_disposed || !mounted) return;
      setState(() => _socketStatus = _SocketStatus.connected);
      _socket!.emit('trip:join', {'tripId': widget.tripId});
    });

    // Status change from owner/agent
    _socket!.on('trip:status_changed', (data) {
      if (_disposed || !mounted) return;
      try {
        final map = data as Map<String, dynamic>;

        // Priorité 1 : trip complet dans le payload → reconstruire le modèle
        final tripData = map['trip'];
        if (tripData != null) {
          try {
            setState(() => _trip = Trip.fromJson(extractData(tripData as Map<String, dynamic>)));
            return;
          } catch (_) {}
        }

        // Priorité 2 : fallback — appliquer seulement le nouveau statut sur le trip existant
        final newStatus = map['status'] as String?;
        if (newStatus != null && _trip != null) {
          setState(() => _trip = _trip!.copyWithStatus(newStatus));
        }
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

        final prevPos = _busPosition;
        final newPos = LatLng(lat, lng);

        // GPS heading : valide seulement si ≥ 0; sinon on calcule depuis le delta
        final gpsHeading = (map['heading'] as num?)?.toDouble() ?? -1;
        double heading = _busHeading;
        if (gpsHeading >= 0) {
          heading = gpsHeading;
        } else if (prevPos != null) {
          final dlat = (prevPos.latitude  - newPos.latitude).abs();
          final dlng = (prevPos.longitude - newPos.longitude).abs();
          if (dlat > 1e-6 || dlng > 1e-6) {
            heading = _bearingBetween(prevPos, newPos);
          }
        }

        setState(() {
          _busPosition = newPos;
          _busHeading  = heading;
          _busSpeed    = (map['speed'] as num?)?.toDouble() ?? _busSpeed;
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
    WidgetsBinding.instance.removeObserver(this);
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
                  routePoints: _routePoints,
                  mapBearing: _mapBearing,
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
  final List<LatLng> routePoints;
  final double mapBearing;
  final void Function(bool hasGesture) onPositionChanged;

  const _MapLayer({
    required this.mapController,
    required this.busPosition,
    required this.busHeading,
    required this.pulseAnim,
    required this.trip,
    required this.routePoints,
    required this.mapBearing,
    required this.onPositionChanged,
  });

  LatLng? get _depLatLng {
    final lat = trip?.departureStationLat;
    final lng = trip?.departureStationLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _arrLatLng {
    final lat = trip?.arrivalStationLat;
    final lng = trip?.arrivalStationLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng get _initialCenter {
    if (busPosition != null) return busPosition!;
    final dep = _depLatLng;
    final arr = _arrLatLng;
    if (dep != null && arr != null) {
      return LatLng(
        (dep.latitude + arr.latitude) / 2,
        (dep.longitude + arr.longitude) / 2,
      );
    }
    return dep ?? arr ?? _defaultCenter;
  }

  double get _initialZoom {
    if (busPosition != null) return 15;
    if (_depLatLng != null && _arrLatLng != null) return 8;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final dep = _depLatLng;
    final arr = _arrLatLng;
    final hasStations = dep != null && arr != null;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        initialRotation: mapBearing,
        onPositionChanged: (pos, hasGesture) => onPositionChanged(hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrlTemplate,
          userAgentPackageName: 'ci.transpro.app',
          maxNativeZoom: 18,
          maxZoom: 22,
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: kRoutePolylineColor,
                strokeWidth: kRoutePolylineWidth,
                strokeCap: StrokeCap.round,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (hasStations) ...[
              Marker(
                point: dep,
                width: 36,
                height: 36,
                child: _StationMarker(
                  color: const Color(0xFF16A34A),
                  icon: Icons.circle,
                ),
              ),
              Marker(
                point: arr,
                width: 36,
                height: 36,
                child: _StationMarker(
                  color: const Color(0xFFDC2626),
                  icon: Icons.location_on,
                ),
              ),
            ],
            if (busPosition != null)
              Marker(
                point: busPosition!,
                width: 80,
                height: 80,
                child: _BusMarker(heading: busHeading, pulseAnim: pulseAnim),
              ),
          ],
        ),
      ],
    );
  }
}

class _StationMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _StationMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// Animated bus marker
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
        child: Image.asset(
          'assets/images/bus_2.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
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
      initialChildSize: 0.25,
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

                  // ── Company ───────────────────────────────────────────────
                  if (trip.tenantName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CompanyLogo(logo: trip.tenantLogo, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              trip.tenantName!,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
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

  String? _timeFor(String step) {
    if (step == 'DEPARTED') return DateFormat('HH:mm').format(departureAt.toLocal());
    if (step == 'ARRIVED' && eta != null) return DateFormat('HH:mm').format(eta!.toLocal());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIdx = steps.indexOf(currentStatus);
    final n = steps.length;

    const green  = Color(0xFF16A34A);
    final inactive = context.divider;

    return Column(
      children: [
        // ── Ligne + dots ───────────────────────────────────────────────────
        SizedBox(
          height: 24,
          child: Row(
            children: List.generate(n, (i) {
              final done   = i < currentIdx;
              final active = i == currentIdx;
              final dotColor = done ? green : active ? brandOrange : inactive;
              // Left connector: green if this step has been reached (i <= currentIdx)
              // Right connector: green if this step is completed (i < currentIdx)
              final leftLineColor  = i <= currentIdx ? green : inactive;
              final rightLineColor = i <  currentIdx ? green : inactive;

              return Expanded(
                child: Row(
                  children: [
                    // Connecteur gauche (sauf premier step)
                    if (i > 0)
                      Expanded(child: Container(height: 2, color: leftLineColor)),

                    // Dot centré
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check, color: Colors.white, size: 12)
                          : active
                          ? Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),

                    // Connecteur droit (sauf dernier step)
                    if (i < n - 1)
                      Expanded(child: Container(height: 2, color: rightLineColor)),
                  ],
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 5),

        // ── Labels alignés sous chaque dot ────────────────────────────────
        Row(
          children: List.generate(n, (i) {
            final step   = steps[i];
            final done   = i < currentIdx;
            final active = i == currentIdx;
            final time   = _timeFor(step);

            // Alignement : gauche pour step 0, droite pour step final, centre sinon
            final align = i == 0
                ? TextAlign.left
                : i == n - 1
                ? TextAlign.right
                : TextAlign.center;

            return Expanded(
              child: Column(
                crossAxisAlignment: i == 0
                    ? CrossAxisAlignment.start
                    : i == n - 1
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
                children: [
                  Text(
                    _tripStatusLabel(step, l10n),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? brandOrange
                          : done
                          ? context.textSecondary
                          : inactive,
                    ),
                    textAlign: align,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (time != null)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active ? brandOrange : context.textMuted,
                      ),
                      textAlign: align,
                    ),
                ],
              ),
            );
          }),
        ),
      ],
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
