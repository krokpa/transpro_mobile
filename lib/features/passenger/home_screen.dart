import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_bell.dart';

final _upcomingTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips', queryParameters: {
    'status': 'SCHEDULED,BOARDING',
    'limit': 10,
  });
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final tripsAsync = ref.watch(_upcomingTripsProvider);
    final fmt = DateFormat('EEE d MMM', 'fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Premium hero app bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: brandCanvas,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [brandCanvas, Color(0xFF1A3A5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circle
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandOrange.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, right: 20,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandOrange.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: brandOrange.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    user.firstName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  'Bonjour, ${user.firstName}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                                const Text(
                                  'Où allez-vous ?',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ]),
                              const Spacer(),
                              const NotificationBell(notificationsRoute: '/passenger/notifications'),
                            ]),
                            const SizedBox(height: 16),
                            // Search bar
                            GestureDetector(
                              onTap: () => context.go('/passenger/search'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(children: [
                                  const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Rechercher un voyage…',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: brandOrange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Collapsed title
            title: const Text('TransPro CI', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: brandOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
              ),
            ),
            actions: const [
              NotificationBell(notificationsRoute: '/passenger/notifications'),
              SizedBox(width: 8),
            ],
          ),

          // ── Quick actions ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(children: [
                _QuickAction(
                  icon: Icons.search_rounded,
                  label: 'Rechercher',
                  color: brandOrange,
                  bg: brandLight,
                  onTap: () => context.go('/passenger/search'),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.confirmation_num_outlined,
                  label: 'Mes billets',
                  color: const Color(0xFF6366F1),
                  bg: const Color(0xFFEEF2FF),
                  onTap: () => context.go('/passenger/bookings'),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.notifications_outlined,
                  label: 'Alertes',
                  color: const Color(0xFF0EA5E9),
                  bg: const Color(0xFFE0F2FE),
                  onTap: () => context.push('/passenger/notifications'),
                ),
              ]),
            ),
          ),

          // ── Upcoming trips ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text(
                      'Prochains départs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/passenger/search'),
                      child: const Text('Voir tout', style: TextStyle(fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  tripsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                    data: (trips) => trips.isEmpty
                        ? const _EmptyState()
                        : Column(
                            children: trips.map((t) => _TripCard(trip: t, fmt: fmt)).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick action chip ─────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Trip trip;
  final DateFormat fmt;
  const _TripCard({required this.trip, required this.fmt});

  static const _classCfg = {
    'VIP':      (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'EXPRESS':  (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'STANDARD': (Color(0xFFF0FDF4), Color(0xFF16A34A)),
  };

  @override
  Widget build(BuildContext context) {
    final cc = _classCfg[trip.tripClass] ?? _classCfg['STANDARD']!;
    final isBoarding = trip.status == 'BOARDING';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/passenger/trip/${trip.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${trip.originCity} → ${trip.destinationCity}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      fmt.format(trip.departureAt.toLocal()),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ]),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${trip.price.toStringAsFixed(0)} F',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: brandOrange),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: cc.$1, borderRadius: BorderRadius.circular(6)),
                    child: Text(trip.tripClass, style: TextStyle(color: cc.$2, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.event_seat_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  '${trip.availableSeats} places',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                if (isBoarding)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.circle, size: 6, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text('Embarquement', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Réserver',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
          child: const Icon(Icons.directions_bus_outlined, size: 34, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),
        const Text('Aucun voyage disponible',
          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Revenez plus tard ou modifiez vos critères.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
      ]),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFDC2626)))),
    ]),
  );
}
