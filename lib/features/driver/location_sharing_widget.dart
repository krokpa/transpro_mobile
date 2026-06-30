import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';

// ── Provider global pour suivre quel tripId est en cours de partage ───────────

final locationSharingProvider =
    StateNotifierProvider<LocationSharingNotifier, String?>((ref) {
  return LocationSharingNotifier(ref);
});

class LocationSharingNotifier extends StateNotifier<String?> {
  final Ref _ref;
  io.Socket? _socket;
  StreamSubscription<Position>? _sub;
  double _speed = 0;

  LocationSharingNotifier(this._ref) : super(null);

  bool get isSharing => state != null;
  String? get activeTripId => state;
  double get currentSpeed => _speed;

  Future<bool> start(BuildContext context, String tripId) async {
    if (state == tripId) return true; // déjà actif
    if (state != null) await stop();

    // Permissions GPS
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission GPS refusée'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Activez le GPS sur votre appareil'),
          backgroundColor: Colors.orange,
        ));
      }
      return false;
    }

    // Socket.io
    final token = _ref.read(authProvider).accessToken;
    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth(token != null ? {'token': token} : <String, dynamic>{})
          .build(),
    );
    _socket!.connect();

    // Rejoindre la room du voyage (pour recevoir ses propres broadcasts aussi)
    _socket!.emit('trip:join', {'tripId': tripId});

    // Stream GPS — filtre 15m, haute précision
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      _speed = pos.speed * 3.6;
      _socket?.emit('location:update', {
        'tripId':  tripId,
        'lat':     pos.latitude,
        'lng':     pos.longitude,
        'heading': pos.heading,
        'speed':   double.parse(_speed.toStringAsFixed(1)),
      });
    });

    state = tripId;
    return true;
  }

  Future<void> stop() async {
    final tripId = state;
    await _sub?.cancel();
    _sub = null;
    if (tripId != null) {
      _socket?.emit('location:update', {'tripId': tripId, 'lat': 0, 'lng': 0});
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _speed = 0;
    state = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}

// ── Widget réutilisable ────────────────────────────────────────────────────────

class LocationSharingButton extends ConsumerWidget {
  final String tripId;
  final String tripStatus;

  const LocationSharingButton({
    super.key,
    required this.tripId,
    required this.tripStatus,
  });

  static const _sharingStatuses = {'BOARDING', 'DEPARTED'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTripId = ref.watch(locationSharingProvider);
    final notifier     = ref.read(locationSharingProvider.notifier);
    final isThisTrip   = activeTripId == tripId;
    final canShare     = _sharingStatuses.contains(tripStatus);

    if (!canShare) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isThisTrip ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isThisTrip ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            if (isThisTrip) {
              await notifier.stop();
            } else {
              await notifier.start(context, tripId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (isThisTrip) ...[
                const _PulsingDot(),
                const SizedBox(width: 8),
                const Text('Partage actif',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              ] else ...[
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text('Partager ma position',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Bandeau vitesse affiché quand actif ───────────────────────────────────────

class LocationSharingBanner extends ConsumerWidget {
  const LocationSharingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTripId = ref.watch(locationSharingProvider);
    final notifier     = ref.read(locationSharingProvider.notifier);

    if (activeTripId == null) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFF16A34A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const _PulsingDot(color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Position partagée en temps réel · ${notifier.currentSpeed.toStringAsFixed(0)} km/h',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        GestureDetector(
          onTap: () => notifier.stop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
            child: const Text('Arrêter', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Dot animé ─────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({this.color = const Color(0xFF22C55E)});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: _anim.value),
      ),
    ),
  );
}
