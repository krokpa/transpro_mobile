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
import '../../core/offline/manifest_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_bell.dart';
import '../../l10n/app_localizations.dart';

final _todayTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.read(authProvider).user!;
  final dio = ref.read(dioProvider);
  final res = await dio.get('/stations/${user.stationId}/trips/today');
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class DeparturesScreen extends ConsumerWidget {
  const DeparturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user!;
    final tripsAsync = ref.watch(_todayTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.departuresTitle),
            if (user.stationName != null)
              Text(
                user.stationName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.textMuted,
                ),
              ),
          ],
        ),
        actions: [
          const NotificationBell(notificationsRoute: '/agent/notifications'),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_todayTripsProvider),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => context.push('/agent/quick-sale'),
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text(l10n.departureQuickSale),
              style: FilledButton.styleFrom(
                backgroundColor: brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (trips) {
          if (trips.isEmpty)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.departure_board_outlined,
                    size: 56,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.departuresNoneToday,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_todayTripsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
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
  bool _sharing = false;
  double _speed = 0;
  StreamSubscription<Position>? _locationSub;
  io.Socket? _socket;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _prefetching = false;
  bool _prefetched = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _prefetched = ManifestCache.hasManifest(widget.trip.id);
  }

  void _startCountdown() {
    _remaining = widget.trip.departureAt.difference(DateTime.now());
    if (_remaining.isNegative) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = widget.trip.departureAt.difference(DateTime.now());
      if (mounted)
        setState(() => _remaining = r.isNegative ? Duration.zero : r);
    });
  }

  Future<void> _prefetchManifest() async {
    if (_prefetching || _prefetched) return;
    setState(() => _prefetching = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips/${widget.trip.id}/manifest');
      final items = extractData(res.data) as List;
      await ManifestCache.saveManifest(
        widget.trip.id,
        items.cast<Map<String, dynamic>>(),
      );
      if (mounted) setState(() => _prefetched = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _prefetching = false);
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative || d.inSeconds == 0) return '—';
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h${m.toString().padLeft(2, '0')}';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  static const _statusCfg = {
    'SCHEDULED': (Color(0xFFF1F5F9), Color(0xFF64748B)),
    'BOARDING': (Color(0xFFFEF9C3), Color(0xFFCA8A04)),
    'DEPARTED': (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'ARRIVED': (Color(0xFFF0F9FF), Color(0xFF0369A1)),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopSharing();
    super.dispose();
  }

  Future<void> _startSharing() async {
    final l10n = AppLocalizations.of(context);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.navScreenLocationDenied),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.agentGpsEnableHint)));
      }
      return;
    }

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

    _locationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          ),
        ).listen((pos) {
          _socket?.emit('location:update', {
            'tripId': widget.trip.id,
            'lat': pos.latitude,
            'lng': pos.longitude,
            'heading': pos.heading,
            'speed': (pos.speed * 3.6).toStringAsFixed(1),
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
      'lat': 0,
      'lng': 0,
    });
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (mounted)
      setState(() {
        _sharing = false;
        _speed = 0;
      });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = widget.trip;
    final cfg = _statusCfg[trip.status] ?? _statusCfg['SCHEDULED']!;
    final occupied = trip.totalSeats - trip.availableSeats;
    final pct = trip.totalSeats > 0 ? occupied / trip.totalSeats : 0.0;
    final isDeparted = trip.status == 'DEPARTED';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.originCity} → ${trip.destinationCity}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            DateFormat(
                              'HH:mm',
                            ).format(trip.departureAt.toLocal()),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: brandOrange,
                            ),
                          ),
                          if (_remaining.inSeconds > 0 &&
                              trip.status == 'SCHEDULED') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _remaining.inMinutes < 30
                                    ? const Color(0xFFFEE2E2)
                                    : context.inputFill,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatCountdown(_remaining),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _remaining.inMinutes < 30
                                      ? const Color(0xFFDC2626)
                                      : context.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.$1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _tripStatusLabel(trip.status, l10n),
                    style: TextStyle(
                      color: cfg.$2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$occupied',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            '/${trip.totalSeats} ${l10n.departurePaxSuffix}',
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: context.divider,
                          valueColor: AlwaysStoppedAnimation(
                            pct > 0.8 ? Colors.red : brandOrange,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trip.tripClass,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      trip.vehiclePlate ?? '—',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/agent/manifest/${trip.id}'),
                    icon: const Icon(Icons.format_list_bulleted, size: 16),
                    label: Text(l10n.departureManifestBtn(occupied)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandOrange,
                      side: BorderSide(
                        color: brandOrange.withValues(alpha: 0.31),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/agent/parcels/${trip.id}'),
                  icon: const Icon(Icons.inventory_2_outlined, size: 15),
                  label: const Text('Colis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _prefetching ? null : _prefetchManifest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _prefetched
                        ? const Color(0xFF16A34A)
                        : context.textSecondary,
                    side: BorderSide(
                      color: _prefetched
                          ? const Color(0xFF16A34A)
                          : context.divider,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: _prefetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _prefetched
                              ? Icons.wifi_off_rounded
                              : Icons.download_outlined,
                          size: 18,
                        ),
                ),
              ],
            ),

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
          ],
        ),
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
    required this.sharing,
    required this.speed,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sharing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const _PulsingDot(color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.departureGpsSharingLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  if (speed > 0)
                    Text(
                      '${speed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                l10n.departureGpsStop,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tagBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandOrange.withValues(alpha: 0.31)),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_fixed, color: brandOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.departureDriverMode,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    l10n.departureSharePosition,
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: brandOrange, size: 18),
          ],
        ),
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

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

String _tripStatusLabel(String s, AppLocalizations l10n) => switch (s) {
  'SCHEDULED' => l10n.tripStatusScheduled,
  'BOARDING' => l10n.tripStatusBoarding,
  'DEPARTED' => l10n.tripStatusDeparted,
  'ARRIVED' => l10n.tripStatusArrived,
  'CANCELLED' => l10n.tripStatusCancelled,
  _ => s,
};
