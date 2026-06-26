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
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fade_slide.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

final _todayTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.read(authProvider).user!;
  final dio = ref.read(dioProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final res = await dio.get(
    '/stations/${user.stationId}/trips',
    queryParameters: {'date': today},
  );
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class DeparturesScreen extends ConsumerWidget {
  const DeparturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    final tripsAsync = ref.watch(_todayTripsProvider);
    final tripsCount = tripsAsync.valueOrNull?.length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_todayTripsProvider.future),
        displacement: 240,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Rich agent header ──────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 265,
              pinned: true,
              stretch: false,
              backgroundColor: brandCanvas,
              iconTheme: const IconThemeData(color: Colors.white),
              actionsIconTheme: const IconThemeData(color: Colors.white),
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.departuresTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (user.stationName != null)
                    Text(
                      user.stationName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
              actions: [
                const NotificationBell(notificationsRoute: '/agent/notifications'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: () => ref.invalidate(_todayTripsProvider),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _AgentHeader(
                  user: user,
                  tripsCount: tripsCount,
                  l10n: l10n,
                  onQuickSale: () => context.push('/agent/quick-sale'),
                ),
              ),
            ),

            // ── Trip list ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              sliver: tripsAsync.when(
                loading: () => SliverToBoxAdapter(child: AppShimmer.tripCards()),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '${l10n.error}: $e',
                        style: TextStyle(color: context.textMuted),
                      ),
                    ),
                  ),
                ),
                data: (trips) {
                  if (trips.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.departure_board_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.departuresNoneToday,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => FadeSlideIn(
                        delay: Duration(milliseconds: (i * 60).clamp(0, 240)),
                        child: _DepartureCard(trip: trips[i]),
                      ),
                      childCount: trips.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Agent header (expanded) ────────────────────────────────────────────────────

class _AgentHeader extends StatelessWidget {
  final User user;
  final int? tripsCount;
  final AppLocalizations l10n;
  final VoidCallback onQuickSale;

  const _AgentHeader({
    required this.user,
    required this.tripsCount,
    required this.l10n,
    required this.onQuickSale,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final rawDate = DateFormat('EEEE d MMMM', locale).format(now);
    final capDate =
        rawDate.isNotEmpty ? rawDate[0].toUpperCase() + rawDate.substring(1) : rawDate;
    final hour = now.hour;
    final greeting = hour < 12 ? 'Bonjour' : 'Bonsoir';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandCanvas, Color(0xFF0F2545)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -28,
            top: 10,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandOrange.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.09),
              ),
            ),
          ),

          // Top content: date + greeting + station
          Positioned(
            top: top + kToolbarHeight + 4,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  capDate,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Greeting row + avatar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, ${user.firstName} 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: brandOrange.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: brandOrange.withValues(alpha: 0.35)),
                            ),
                            child: const Text(
                              'Agent',
                              style: TextStyle(
                                color: brandOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: UserAvatarWidget(
                        firstName: user.firstName,
                        lastName: user.lastName,
                        avatar: user.avatar,
                        size: 50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Station
                if (user.stationName != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user.stationName!,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Bottom: trip count chip + Quick Sale — ancré en bas
          Positioned(
            left: 20,
            right: 20,
            bottom: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.departure_board_outlined,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        tripsCount != null
                            ? '$tripsCount voyage${tripsCount == 1 ? '' : 's'}'
                            : '— voyages',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onQuickSale,
                    icon: const Icon(Icons.bolt_rounded, size: 15),
                    label: Text(l10n.departureQuickSale),
                    style: FilledButton.styleFrom(
                      backgroundColor: brandOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
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
    'BOARDING':  (Color(0xFFFEF9C3), Color(0xFFCA8A04)),
    'DEPARTED':  (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'ARRIVED':   (Color(0xFFF0F9FF), Color(0xFF0369A1)),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationSub?.cancel();
    _locationSub = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }

  Future<void> _startSharing() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;

    final granted = await PermissionService.requestLocation(context);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.navScreenLocationDenied),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.agentGpsEnableHint)));
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

    _locationSub = Geolocator.getPositionStream(
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
    if (mounted) setState(() { _sharing = false; _speed = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = widget.trip;
    final cfg = _statusCfg[trip.status] ?? _statusCfg['SCHEDULED']!;
    final occupied = trip.totalSeats - trip.availableSeats;
    final pct = trip.totalSeats > 0 ? occupied / trip.totalSeats : 0.0;
    final isDeparted = trip.status == 'DEPARTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status strip ────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: cfg.$1,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: cfg.$2, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tripStatusLabel(trip.status, l10n),
                    style: TextStyle(
                        color: cfg.$2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (trip.vehiclePlate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cfg.$2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        trip.vehiclePlate!,
                        style: TextStyle(
                          color: cfg.$2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Card body ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route visualization
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.originCity,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: brandOrange,
                                  shape: BoxShape.circle),
                            ),
                            Container(
                              width: 32,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [brandOrange, context.divider],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            Icon(Icons.location_on_rounded,
                                size: 13, color: context.textMuted),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          trip.destinationCity,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Time + countdown + class
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: brandOrange,
                        ),
                      ),
                      if (_remaining.inSeconds > 0 &&
                          trip.status == 'SCHEDULED') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _remaining.inMinutes < 30
                                ? const Color(0xFFFEE2E2)
                                : context.inputFill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatCountdown(_remaining),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _remaining.inMinutes < 30
                                  ? const Color(0xFFDC2626)
                                  : context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.inputFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip.tripClass,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Occupancy
                  Row(
                    children: [
                      Text(
                        '$occupied',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        '/${trip.totalSeats} ${l10n.departurePaxSuffix}',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: context.divider,
                            valueColor: AlwaysStoppedAnimation(
                              pct > 0.85 ? Colors.red : brandOrange,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pct > 0.85
                              ? Colors.red
                              : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Action row
                  Row(
                    children: [
                      _SmallAction(
                        icon: Icons.luggage_outlined,
                        label: 'Bagages',
                        color: const Color(0xFF7C3AED),
                        onTap: () =>
                            context.push('/agent/luggage/${trip.id}'),
                      ),
                      const SizedBox(width: 8),
                      _SmallAction(
                        icon: Icons.inventory_2_outlined,
                        label: 'Colis',
                        color: const Color(0xFF2563EB),
                        onTap: () =>
                            context.push('/agent/parcels/${trip.id}'),
                      ),
                      const Spacer(),
                      // Offline prefetch
                      Tooltip(
                        message: _prefetched
                            ? 'Manifest hors-ligne prêt'
                            : 'Télécharger le manifest hors-ligne',
                        child: Material(
                          color: _prefetched
                              ? const Color(0xFFDCFCE7)
                              : context.inputFill,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: _prefetching ? null : _prefetchManifest,
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                child: _prefetching
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.textMuted,
                                        ),
                                      )
                                    : Icon(
                                        _prefetched
                                            ? Icons.wifi_off_rounded
                                            : Icons.download_outlined,
                                        size: 18,
                                        color: _prefetched
                                            ? const Color(0xFF16A34A)
                                            : context.textMuted,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Manifest full-width
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/agent/manifest/${trip.id}'),
                      icon: const Icon(Icons.checklist_rounded, size: 16),
                      label: Text(l10n.departureManifestBtn(occupied)),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            brandOrange.withValues(alpha: 0.10),
                        foregroundColor: brandOrange,
                        elevation: 0,
                        minimumSize: const Size(0, 38),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  // GPS banner (DEPARTED only)
                  if (isDeparted) ...[
                    const SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}

// ── Small action button ────────────────────────────────────────────────────────

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: context.isDark ? 0.15 : 0.08),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          color: Color(0xFF16A34A), fontSize: 12),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: Text(l10n.departureGpsStop,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tagBg,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: brandOrange.withValues(alpha: 0.31)),
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
                    style: TextStyle(
                        color: context.textMuted, fontSize: 11),
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
      decoration:
          BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

String _tripStatusLabel(String s, AppLocalizations l10n) => switch (s) {
  'SCHEDULED' => l10n.tripStatusScheduled,
  'BOARDING'  => l10n.tripStatusBoarding,
  'DEPARTED'  => l10n.tripStatusDeparted,
  'ARRIVED'   => l10n.tripStatusArrived,
  'CANCELLED' => l10n.tripStatusCancelled,
  _ => s,
};
