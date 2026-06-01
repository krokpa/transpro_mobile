import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/map_config.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class StationNavigationScreen extends StatefulWidget {
  final String stationName;
  final double stationLat;
  final double stationLng;

  const StationNavigationScreen({
    super.key,
    required this.stationName,
    required this.stationLat,
    required this.stationLng,
  });

  @override
  State<StationNavigationScreen> createState() => _StationNavigationScreenState();
}

class _StationNavigationScreenState extends State<StationNavigationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;

  LatLng? _userPos;
  double? _distanceM;
  bool _arrived = false;
  bool _locationDenied = false;
  bool _followUser = true;

  static const double _arrivalRadius = 50.0; // metres

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (!mounted) return;
    final granted = await PermissionService.requestLocation(context);
    if (!granted) {
      setState(() => _locationDenied = true);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationDenied = true);
      return;
    }

    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      final dist = _haversine(pos.latitude, pos.longitude, widget.stationLat, widget.stationLng);
      setState(() {
        _userPos = userLatLng;
        _distanceM = dist;
        if (dist <= _arrivalRadius) _arrived = true;
      });
      if (_followUser) {
        _mapController.move(userLatLng, _mapController.camera.zoom);
      }
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  String _formatDistance(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  String _estimatedTime(double m) {
    // ~4 km/h walking pace
    final mins = (m / 67).round();
    if (mins < 1) return '< 1 min';
    return '$mins min';
  }

  void _centerOnStation() {
    setState(() => _followUser = false);
    _mapController.move(LatLng(widget.stationLat, widget.stationLng), 16.0);
  }

  void _centerOnUser() {
    if (_userPos == null) return;
    setState(() => _followUser = true);
    _mapController.move(_userPos!, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stationLatLng = LatLng(widget.stationLat, widget.stationLng);
    final initialCenter = _userPos ?? stationLatLng;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) setState(() => _followUser = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrlTemplate,
                userAgentPackageName: 'ci.transpro.app',
              ),

              // Route line
              if (_userPos != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [_userPos!, stationLatLng],
                    color: brandOrange.withValues(alpha: 0.75),
                    strokeWidth: 4,
                    pattern: StrokePattern.dashed(segments: [12, 6]),
                  ),
                ]),

              // Station marker
              MarkerLayer(markers: [
                Marker(
                  point: stationLatLng,
                  width: 56,
                  height: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: brandOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [BoxShadow(color: brandOrange.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 20),
                      ),
                      CustomPaint(size: const Size(12, 8), painter: _TrianglePainter(brandOrange)),
                    ],
                  ),
                ),
              ]),

              // User position marker
              if (_userPos != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userPos!,
                    width: 48,
                    height: 48,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
                      ),
                    ),
                  ),
                ]),
            ],
          ),

          // ── Top bar ────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                _MapBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: Row(children: [
                      const Icon(Icons.location_city_rounded, color: brandOrange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.stationName,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── Location denied banner ─────────────────────────────────────────
          if (_locationDenied)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_off_outlined, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.navScreenLocationDenied,
                        style: const TextStyle(fontSize: 13, color: Colors.red)),
                    ),
                  ]),
                ),
              ),
            ),

          // ── Arrived banner ─────────────────────────────────────────────────
          if (_arrived)
            Positioned(
              bottom: 170,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(l10n.navScreenArrived,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
            ),

          // ── Bottom info card ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
                ),
                child: _locationDenied
                    ? Text(l10n.navScreenNoDistance,
                        style: TextStyle(fontSize: 13, color: context.textMuted), textAlign: TextAlign.center)
                    : _userPos == null
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange)),
                            const SizedBox(width: 10),
                            Text(l10n.navScreenLocating, style: TextStyle(fontSize: 14, color: context.textSecondary)),
                          ])
                        : Row(children: [
                            _InfoPill(
                              icon: Icons.straighten,
                              label: l10n.navScreenDistance,
                              value: _formatDistance(_distanceM!),
                              color: brandOrange,
                            ),
                            const SizedBox(width: 12),
                            _InfoPill(
                              icon: Icons.directions_walk,
                              label: l10n.navScreenWalking,
                              value: _estimatedTime(_distanceM!),
                              color: const Color(0xFF3B82F6),
                            ),
                            const Spacer(),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              _MapBtn(icon: Icons.location_city_outlined, onTap: _centerOnStation, size: 36),
                              const SizedBox(height: 6),
                              _MapBtn(icon: Icons.my_location, onTap: _centerOnUser, size: 36,
                                active: _followUser),
                            ]),
                          ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;

  const _MapBtn({required this.icon, required this.onTap, this.size = 40, this.active = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: active ? brandOrange : context.cardBg,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
      ),
      child: Icon(icon, size: size * 0.5, color: active ? Colors.white : context.textPrimary),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: context.textMuted)),
    ]),
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
  ]);
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
