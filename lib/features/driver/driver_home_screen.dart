import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import 'location_sharing_widget.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _driverMeProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/me');
  return extractData(res.data) as Map<String, dynamic>;
});

final _todayTripsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/trips/today');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _upcomingTripsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/driver-space/trips/upcoming');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

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
    'BOARDING': 'Commencer l\'embarquement',
    'DEPARTED': 'Marquer comme parti',
    'ARRIVED':  'Marquer comme arrivé',
  };

  Future<void> _updateStatus(BuildContext ctx, WidgetRef ref, String tripId, String status) async {
    try {
      await ref.read(dioProvider).patch('/driver-space/trips/$tripId/status', data: {'status': status});
      ref.invalidate(_todayTripsProvider);
      ref.invalidate(_upcomingTripsProvider);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: const Text('Statut mis à jour'), backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(authProvider).user;
    final meAsync       = ref.watch(_driverMeProvider);
    final todayAsync    = ref.watch(_todayTripsProvider);
    final upcomingAsync = ref.watch(_upcomingTripsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const LocationSharingBanner(),
          Expanded(child: RefreshIndicator(
        color: brandOrange,
        onRefresh: () async {
          ref.invalidate(_driverMeProvider);
          ref.invalidate(_todayTripsProvider);
          ref.invalidate(_upcomingTripsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB923C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                            ),
                            child: UserAvatarWidget(
                              firstName: user?.firstName ?? '',
                              lastName: user?.lastName ?? '',
                              avatar: user?.avatar,
                              size: 46,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Bonjour,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 1),
                            Text(user?.firstName ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          ]),
                        ]),
                        meAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (data) {
                            final driver = data['driver'] as Map<String, dynamic>?;
                            final isAvail = driver?['isAvailable'] as bool? ?? true;
                            return GestureDetector(
                              onTap: () async {
                                await ref.read(dioProvider).patch('/driver-space/availability', data: {'isAvailable': !isAvail});
                                ref.invalidate(_driverMeProvider);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isAvail ? Colors.white : Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAvail ? const Color(0xFF22C55E) : Colors.white54,
                                  )),
                                  const SizedBox(width: 6),
                                  Text(isAvail ? 'Disponible' : 'Indisponible',
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: isAvail ? brandOrange : Colors.white70,
                                    )),
                                ]),
                              ),
                            );
                          },
                        ),
                      ]),

                      // Stats
                      meAsync.when(
                        loading: () => const SizedBox(height: 60),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (data) {
                          final stats = data['stats'] as Map<String, dynamic>?;
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(children: [
                              _StatPill(label: 'Ce mois', value: '${stats?['tripsThisMonth'] ?? 0}'),
                              const SizedBox(width: 10),
                              _StatPill(label: 'Note', value: stats?['avgRating'] != null
                                  ? '${(stats!['avgRating'] as num).toStringAsFixed(1)}/5' : '—'),
                              const SizedBox(width: 10),
                              _StatPill(label: 'Réalisation', value: stats?['completionRate'] != null
                                  ? '${stats!['completionRate']}%' : '—'),
                            ]),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Today's trips ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(children: [
                  Icon(Icons.wb_sunny_outlined, size: 16, color: brandOrange),
                  const SizedBox(width: 6),
                  const Text("Aujourd'hui", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: brandDark)),
                  const Spacer(),
                  todayAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (t) => Text('${t.length} voyage${t.length != 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                ]),
              ),
            ),

            todayAsync.when(
              loading: () => SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppShimmer.listTiles(),
              )),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (trips) => trips.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyCard(icon: Icons.directions_bus_outlined, message: "Aucun voyage aujourd'hui"),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final trip = trips[i];
                            final nextStates = (_nextStatus[trip['status']] ?? []) as List;
                            return _TripCard(
                              trip: trip,
                              statusCfg: _statusCfg,
                              nextStates: nextStates.cast<String>(),
                              actionLabel: _actionLabel,
                              onAction: (s) => _updateStatus(context, ref, trip['id'] as String, s),
                            );
                          },
                          childCount: trips.length,
                        ),
                      ),
                    ),
            ),

            // ── Upcoming ──
            upcomingAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (upcoming) {
                if (upcoming.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(children: [
                        const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 6),
                        const Text('Prochains voyages', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: brandDark)),
                        const Spacer(),
                        Text('${upcoming.length} à venir', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ]),
                    ),
                    ...upcoming.take(3).map((trip) {
                      final cfg = _statusCfg[trip['status']] ?? _statusCfg['SCHEDULED']!;
                      final dept = trip['departureAt'] as String? ?? '';
                      final route = trip['route'] as Map<String, dynamic>?;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                              Text(_fmtDay(dept), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              Text(_fmtDayNum(dept), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark, height: 1.1)),
                              Text(_fmtTime(dept), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ]),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (route != null)
                                Text('${route['originCity']?['name']} → ${route['destinationCity']?['name']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(_fmtDate(dept), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(8)),
                              child: Text(cfg.$3, style: TextStyle(fontSize: 11, color: cfg.$2, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                      );
                    }),
                  ]),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      )),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ]),
    ),
  );
}

class _TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final Map<String, (Color, Color, String)> statusCfg;
  final List<String> nextStates;
  final Map<String, String> actionLabel;
  final Future<void> Function(String) onAction;
  const _TripCard({required this.trip, required this.statusCfg, required this.nextStates, required this.actionLabel, required this.onAction});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final trip    = widget.trip;
    final dept    = trip['departureAt'] as String? ?? '';
    final status  = trip['status'] as String? ?? 'SCHEDULED';
    final route   = trip['route'] as Map<String, dynamic>?;
    final vehicle = trip['vehicle'] as Map<String, dynamic>?;
    final cfg     = widget.statusCfg[status] ?? widget.statusCfg['SCHEDULED']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Time
            Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Text(_fmtTime(dept), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: brandOrange, height: 1)),
              Text(_fmtShortDate(dept), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (route != null)
                Text('${route['originCity']?['name']} → ${route['destinationCity']?['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (vehicle != null) ...[
                  const Icon(Icons.directions_bus_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(vehicle['licensePlate'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'monospace')),
                ],
              ]),
              const SizedBox(height: 6),
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
            tripStatus: trip['status'] as String? ?? '',
          ),
        ),

        if (widget.nextStates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: widget.nextStates.map((next) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilledButton(
                  onPressed: _loading ? null : () async {
                    setState(() => _loading = true);
                    await widget.onAction(next);
                    if (mounted) setState(() => _loading = false);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: brandOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.actionLabel[next] ?? next,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ),
              ),
            )).toList()),
          ),

        if (trip['status'] == 'ARRIVED')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('✓ Voyage terminé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)))),
            ),
          ),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Center(child: Column(children: [
        Icon(icon, size: 36, color: const Color(0xFFE2E8F0)),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      ])),
    ),
  );
}

String _fmtTime(String? d) {
  if (d == null || d.isEmpty) return '—';
  try { final dt = DateTime.parse(d).toLocal(); return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'; }
  catch (_) { return '—'; }
}

String _fmtDay(String? d) {
  if (d == null || d.isEmpty) return '—';
  try { final dt = DateTime.parse(d).toLocal(); const days = ['lun','mar','mer','jeu','ven','sam','dim']; return days[(dt.weekday-1)%7]; }
  catch (_) { return '—'; }
}

String _fmtDayNum(String? d) {
  if (d == null || d.isEmpty) return '—';
  try { return DateTime.parse(d).toLocal().day.toString(); } catch (_) { return '—'; }
}

String _fmtDate(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    const months = ['','jan','fév','mars','avr','mai','juin','juil','août','sept','oct','nov','déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  } catch (_) { return '—'; }
}

String _fmtShortDate(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    const months = ['','jan','fév','mars','avr','mai','juin','juil','août','sept','oct','nov','déc'];
    return '${dt.day} ${months[dt.month]}';
  } catch (_) { return '—'; }
}
