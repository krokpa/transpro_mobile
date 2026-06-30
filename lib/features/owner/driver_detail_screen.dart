import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _driverProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id');
  return extractData(res.data) as Map<String, dynamic>;
});

final _statsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id/stats');
  return extractData(res.data) as Map<String, dynamic>;
});

final _scheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String id, String month})>((ref, args) async {
  final res = await ref.read(dioProvider)
      .get('/drivers/${args.id}/schedule', queryParameters: {'month': args.month});
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _absencesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id/absences');
  return (extractData(res.data) as List).cast<Map<String, dynamic>>();
});

final _evaluationsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(dioProvider).get('/drivers/$id/evaluations');
  return extractData(res.data) as Map<String, dynamic>;
});

// ── Shared helpers ─────────────────────────────────────────────────────────────

const _statusCfg = {
  'SCHEDULED': (Color(0xFFEFF6FF), Color(0xFF2563EB), 'Planifié'),
  'BOARDING':  (Color(0xFFFFFBEB), Color(0xFFD97706), 'Embarquement'),
  'DEPARTED':  (Color(0xFFF0FDF4), Color(0xFF16A34A), 'En route'),
  'ARRIVED':   (Color(0xFFF8FAFC), Color(0xFF64748B), 'Arrivé'),
  'CANCELLED': (Color(0xFFFEF2F2), Color(0xFFDC2626), 'Annulé'),
  'DELAYED':   (Color(0xFFFFF7ED), Color(0xFFEA580C), 'Retardé'),
};

const _absenceColor = {
  'LEAVE': Color(0xFF3B82F6),
  'SICK':  Color(0xFFEF4444),
  'OTHER': Color(0xFF94A3B8),
};

const _absenceLabel = {'LEAVE': 'Congé', 'SICK': 'Maladie', 'OTHER': 'Autre'};

String _fmtDateFull(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    const months = ['', 'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  } catch (_) { return d.substring(0, 10); }
}

String _fmtTime(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  } catch (_) { return '—'; }
}

String _fmtDay(String? d) {
  if (d == null || d.isEmpty) return '—';
  try {
    final dt = DateTime.parse(d).toLocal();
    const days = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    return days[(dt.weekday - 1) % 7];
  } catch (_) { return '—'; }
}

Widget _starRow(double value, {double size = 14}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < value.round() ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: i < value.round() ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
    )),
  );
}

Widget _subScore(String label, num? value) {
  if (value == null) return const SizedBox.shrink();
  final pct = (value / 5).clamp(0.0, 1.0);
  return Row(children: [
    SizedBox(width: 80, child: Text(label,
      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: pct, minHeight: 5,
        backgroundColor: const Color(0xFFF1F5F9),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
      ),
    )),
    const SizedBox(width: 8),
    Text(value.toStringAsFixed(1),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
  ]);
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class DriverDetailScreen extends ConsumerStatefulWidget {
  final String driverId;
  const DriverDetailScreen({super.key, required this.driverId});

  @override
  ConsumerState<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends ConsumerState<DriverDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late String _month;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  String get _monthLabel {
    const months = ['', 'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
                    'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];
    final parts = _month.split('-');
    final m = int.tryParse(parts[1]) ?? 0;
    return '${m < months.length ? months[m] : m} ${parts[0]}';
  }

  void _prevMonth() {
    setState(() {
      final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
      final p = DateTime(d.year, d.month - 1);
      _month = '${p.year}-${p.month.toString().padLeft(2, '0')}';
    });
  }

  void _nextMonth() {
    setState(() {
      final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
      final n = DateTime(d.year, d.month + 1);
      _month = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _toggleAvailability(bool current) async {
    try {
      await ref.read(dioProvider).patch(
        '/drivers/${widget.driverId}',
        data: {'isAvailable': !current},
      );
      ref.invalidate(_driverProvider(widget.driverId));
      ref.invalidate(_statsProvider(widget.driverId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverAsync = ref.watch(_driverProvider(widget.driverId));
    final statsAsync  = ref.watch(_statsProvider(widget.driverId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: driverAsync.when(
        loading: () => const _LoadingSkeleton(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (driver) {
          final firstName  = driver['firstName'] as String? ?? '';
          final lastName   = driver['lastName'] as String? ?? '';
          final phone      = driver['phone'] as String? ?? '';
          final license    = driver['licenseNumber'] as String? ?? '';
          final expiry     = driver['licenseExpiry'] as String?;
          final isAvail    = driver['isAvailable'] as bool? ?? true;
          final initials   = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

          int? daysToExpiry;
          bool licenseExpired = false;
          bool licenseWarn = false;
          if (expiry != null) {
            try {
              final exp = DateTime.parse(expiry);
              daysToExpiry = exp.difference(DateTime.now()).inDays;
              licenseExpired = daysToExpiry < 0;
              licenseWarn = !licenseExpired && daysToExpiry <= 60;
            } catch (_) {}
          }

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: brandOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _ProfileHeader(
                    initials: initials,
                    firstName: firstName,
                    lastName: lastName,
                    phone: phone,
                    license: license,
                    expiry: expiry,
                    isAvailable: isAvail,
                    licenseExpired: licenseExpired,
                    licenseWarn: licenseWarn,
                    daysToExpiry: daysToExpiry,
                    onToggleAvail: () => _toggleAvailability(isAvail),
                    statsAsync: statsAsync,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_outlined, size: 16), text: 'Aperçu'),
                    Tab(icon: Icon(Icons.calendar_month_outlined, size: 16), text: 'Planning'),
                    Tab(icon: Icon(Icons.event_busy_outlined, size: 16), text: 'Absences'),
                    Tab(icon: Icon(Icons.star_outline_rounded, size: 16), text: 'Évaluations'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  driverId: widget.driverId,
                  month: _month,
                  statsAsync: statsAsync,
                  onGoToSchedule: () => _tabs.animateTo(1),
                  onGoToAbsences: () => _tabs.animateTo(2),
                ),
                _ScheduleTab(
                  driverId: widget.driverId,
                  month: _month,
                  monthLabel: _monthLabel,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                ),
                _AbsencesTab(driverId: widget.driverId),
                _EvaluationsTab(driverId: widget.driverId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String initials, firstName, lastName, phone, license;
  final String? expiry;
  final bool isAvailable, licenseExpired, licenseWarn;
  final int? daysToExpiry;
  final VoidCallback onToggleAvail;
  final AsyncValue<Map<String, dynamic>> statsAsync;

  const _ProfileHeader({
    required this.initials, required this.firstName, required this.lastName,
    required this.phone, required this.license, required this.expiry,
    required this.isAvailable, required this.licenseExpired,
    required this.licenseWarn, required this.daysToExpiry,
    required this.onToggleAvail, required this.statsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text(initials,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandOrange))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$firstName $lastName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(phone, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 3),
                  Text(license, style: const TextStyle(fontSize: 11, color: Colors.white60, fontFamily: 'monospace')),
                ])),
                // Availability toggle
                GestureDetector(
                  onTap: onToggleAvail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAvailable ? const Color(0xFF22C55E) : Colors.white54,
                      )),
                      const SizedBox(width: 5),
                      Text(
                        isAvailable ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAvailable ? brandOrange : Colors.white70,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),

              const SizedBox(height: 14),

              // License badge
              if (licenseExpired)
                _LicenseBadge(color: const Color(0xFFFEE2E2), textColor: const Color(0xFFDC2626),
                  icon: Icons.warning_amber_rounded,
                  label: 'Permis expiré${daysToExpiry != null ? " (${daysToExpiry!.abs()} j)" : ""}')
              else if (licenseWarn)
                _LicenseBadge(color: const Color(0xFFFFF7ED), textColor: const Color(0xFFEA580C),
                  icon: Icons.warning_amber_rounded,
                  label: 'Permis expire dans ${daysToExpiry ?? "?"} jour${(daysToExpiry ?? 0) > 1 ? "s" : ""}')
              else
                _LicenseBadge(color: Colors.white24, textColor: Colors.white,
                  icon: Icons.verified_outlined,
                  label: expiry != null ? 'Permis valide · exp. ${_fmtDateFull(expiry)}' : 'Permis valide'),

              const SizedBox(height: 12),

              // Stats chips
              statsAsync.when(
                loading: () => Row(children: List.generate(3, (_) =>
                  Expanded(child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 44, decoration: BoxDecoration(
                      color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                  )))),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(children: [
                  _StatChip(
                    icon: Icons.directions_bus_outlined,
                    label: 'Ce mois',
                    value: '${stats['tripsThisMonth'] ?? 0}',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.star_rounded,
                    label: 'Note',
                    value: stats['avgRating'] != null
                        ? (stats['avgRating'] as num).toStringAsFixed(1)
                        : '—',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Réalisation',
                    value: stats['completionRate'] != null
                        ? '${stats['completionRate']}%'
                        : '—',
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicenseBadge extends StatelessWidget {
  final Color color, textColor;
  final IconData icon;
  final String label;
  const _LicenseBadge({required this.color, required this.textColor, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: textColor),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ])),
      ]),
    ),
  );
}

// ── Overview tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final String driverId, month;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final VoidCallback onGoToSchedule, onGoToAbsences;

  const _OverviewTab({
    required this.driverId, required this.month,
    required this.statsAsync, required this.onGoToSchedule,
    required this.onGoToAbsences,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(_scheduleProvider((id: driverId, month: month)));
    final evalsAsync    = ref.watch(_evaluationsProvider(driverId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // Performance card
        statsAsync.when(
          loading: () => _shimmerCard(100),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) {
            final avg     = (stats['avgRating'] as num?)?.toDouble();
            final avgP    = (stats['avgPunctuality'] as num?);
            final avgS    = (stats['avgSafety'] as num?);
            final avgSvc  = (stats['avgService'] as num?);
            final evalCnt = stats['evaluationCount'] as int? ?? 0;
            final total   = stats['tripsTotal'] as int? ?? 0;
            final pending = stats['absencesPending'] as int? ?? 0;

            return Column(children: [
              // KPI row
              Row(children: [
                _KpiCard(label: 'Total voyages', value: '$total', icon: Icons.route_outlined, color: brandOrange),
                const SizedBox(width: 12),
                _KpiCard(label: 'Absences / an', value: '${stats['absencesThisYear'] ?? 0}',
                  icon: Icons.event_busy_outlined,
                  color: pending > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
              ]),
              const SizedBox(height: 12),

              // Rating card
              if (evalCnt > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      const Text('Performance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
                      const Spacer(),
                      Text('$evalCnt éval.', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text(avg?.toStringAsFixed(1) ?? '—',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: brandDark)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _starRow(avg ?? 0, size: 18),
                        const SizedBox(height: 4),
                        const Text('/5 · moyenne globale',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ]),
                    ]),
                    if (avgP != null || avgS != null || avgSvc != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 12),
                      if (avgP != null) _subScore('Ponctualité', avgP),
                      if (avgP != null) const SizedBox(height: 8),
                      if (avgS != null) _subScore('Sécurité', avgS),
                      if (avgS != null) const SizedBox(height: 8),
                      if (avgSvc != null) _subScore('Service', avgSvc),
                    ],
                  ]),
                ),

              // Pending absences alert
              if (pending > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      '$pending absence${pending > 1 ? "s" : ""} en attente d\'approbation',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                    )),
                    TextButton(
                      onPressed: onGoToAbsences,
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFEA580C), padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: const Text('Voir →', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),
              ],
            ]);
          },
        ),

        const SizedBox(height: 16),

        // Upcoming trips
        _SectionHeader(
          icon: Icons.calendar_month_outlined,
          title: 'Voyages ce mois',
          actionLabel: 'Tout voir',
          onAction: onGoToSchedule,
        ),
        const SizedBox(height: 8),
        scheduleAsync.when(
          loading: () => _shimmerCard(140),
          error: (e, _) => const SizedBox.shrink(),
          data: (trips) => trips.isEmpty
              ? _EmptyCard(icon: Icons.directions_bus_outlined, message: 'Aucun voyage ce mois')
              : Column(
                  children: trips.take(4).map((trip) => _TripCard(trip: trip)).toList(),
                ),
        ),

        const SizedBox(height: 16),

        // Latest evaluations
        evalsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (data) {
            final evals = (data['evaluations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            if (evals.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(icon: Icons.star_outline_rounded, title: 'Dernières évaluations'),
              const SizedBox(height: 8),
              ...evals.take(3).map((ev) => _EvalCard(ev: ev, driverId: driverId, showDelete: false)),
            ]);
          },
        ),
      ],
    );
  }
}

Widget _shimmerCard(double height) => Container(
  height: height,
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
);

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: brandDark)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.icon, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: brandOrange),
    const SizedBox(width: 6),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
    const Spacer(),
    if (actionLabel != null && onAction != null)
      GestureDetector(
        onTap: onAction,
        child: Text(actionLabel!, style: TextStyle(fontSize: 12, color: brandOrange, fontWeight: FontWeight.w600)),
      ),
  ]);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF1F5F9)),
    ),
    child: Center(child: Column(children: [
      Icon(icon, size: 32, color: const Color(0xFFE2E8F0)),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
    ])),
  );
}

// ── Shared trip card ───────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dept    = trip['departureTime'] as String?;
    final status  = trip['status'] as String? ?? 'SCHEDULED';
    final route   = trip['route'] as Map<String, dynamic>?;
    final vehicle = trip['vehicle'] as Map<String, dynamic>?;
    final avail   = trip['availableSeats'] as int?;
    final total   = trip['totalSeats'] as int?;
    final cfg = _statusCfg[status] ?? _statusCfg['SCHEDULED']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Row(children: [
        // Date column
        Container(
          width: 44, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(_fmtDay(dept),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: brandOrange)),
            Text(dept != null ? DateTime.parse(dept).toLocal().day.toString() : '—',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brandOrange, height: 1.1)),
            Text(_fmtTime(dept),
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (route != null)
            Text('${route['origin']} → ${route['destination']}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            if (vehicle != null) ...[
              const Icon(Icons.directions_bus_outlined, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 3),
              Text(vehicle['plate'] as String? ?? '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
              const SizedBox(width: 8),
            ],
            if (avail != null && total != null) ...[
              const Icon(Icons.airline_seat_recline_normal_outlined, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 3),
              Text('$avail/$total', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
          child: Text(cfg.$3, style: TextStyle(color: cfg.$2, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Schedule tab ───────────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  final String driverId, month, monthLabel;
  final VoidCallback onPrev, onNext;
  const _ScheduleTab({
    required this.driverId, required this.month,
    required this.monthLabel, required this.onPrev, required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_scheduleProvider((id: driverId, month: month)));

    return Column(children: [
      // Month selector
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrev,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8FAFC)),
          ),
          Text(monthLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF8FAFC)),
          ),
        ]),
      ),
      Expanded(child: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (trips) => trips.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun trajet en $monthLabel', style: TextStyle(color: Colors.grey[400])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: trips.length,
                itemBuilder: (_, i) => _TripCard(trip: trips[i]),
              ),
      )),
    ]);
  }
}

// ── Absences tab ───────────────────────────────────────────────────────────────

class _AbsencesTab extends ConsumerWidget {
  final String driverId;
  const _AbsencesTab({required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_absencesProvider(driverId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Déclarer', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (absences) => absences.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucune absence enregistrée', style: TextStyle(color: Colors.grey[400])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: absences.length,
                itemBuilder: (_, i) {
                  final a = absences[i];
                  final type     = a['type'] as String? ?? 'OTHER';
                  final approved = a['approved'] as bool? ?? false;
                  final start    = a['startDate'] as String?;
                  final end      = a['endDate'] as String?;
                  final reason   = a['reason'] as String?;

                  int days = 1;
                  if (start != null && end != null) {
                    try { days = DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1; } catch (_) {}
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0,2))],
                    ),
                    child: Row(children: [
                      // Color bar
                      Container(
                        width: 5, height: 70,
                        decoration: BoxDecoration(
                          color: _absenceColor[type] ?? const Color(0xFF94A3B8),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_absenceColor[type] ?? const Color(0xFF94A3B8)).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_absenceLabel[type] ?? type,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _absenceColor[type] ?? const Color(0xFF64748B))),
                            ),
                            const SizedBox(width: 6),
                            Text('· $days jour${days > 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: approved ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                approved ? '✓ Approuvée' : '⏳ En attente',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: approved ? const Color(0xFF16A34A) : const Color(0xFFEA580C)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 5),
                          Text('${_fmtDateFull(start)} — ${_fmtDateFull(end)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark)),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(reason, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ]),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (!approved)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF22C55E), size: 22),
                              onPressed: () => _approve(a['id'] as String, ref, context),
                              tooltip: 'Approuver',
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFCBD5E1), size: 22),
                            onPressed: () => _delete(a['id'] as String, ref, context),
                          ),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _approve(String absenceId, WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(dioProvider).patch('/drivers/$driverId/absences/$absenceId', data: {'approved': true});
      ref.invalidate(_absencesProvider(driverId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Absence approuvée'), backgroundColor: Color(0xFF22C55E)),
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(String absenceId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette absence ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/drivers/$driverId/absences/$absenceId');
      ref.invalidate(_absencesProvider(driverId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddAbsenceSheet(
        driverId: driverId,
        onSaved: () => ref.invalidate(_absencesProvider(driverId)),
      ),
    );
  }
}

// ── Evaluations tab ────────────────────────────────────────────────────────────

class _EvaluationsTab extends ConsumerWidget {
  final String driverId;
  const _EvaluationsTab({required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_evaluationsProvider(driverId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Évaluer', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (data) {
          final avg   = (data['averageRating'] as num?)?.toDouble() ?? 0;
          final evals = (data['evaluations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return CustomScrollView(
            slivers: [
              if (evals.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
                      ),
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(avg.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: brandDark, height: 1)),
                          const Text('/5', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                        ]),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _starRow(avg, size: 20),
                          const SizedBox(height: 4),
                          Text('${evals.length} évaluation${evals.length > 1 ? "s" : ""}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ])),
                      ]),
                    ),
                  ),
                ),
              if (evals.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_outline_rounded, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('Aucune évaluation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Text('Appuyez sur + pour évaluer ce chauffeur', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ])),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _EvalCard(ev: evals[i], driverId: driverId, showDelete: true,
                        onDeleted: () => ref.invalidate(_evaluationsProvider(driverId))),
                      childCount: evals.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEvaluationSheet(
        driverId: driverId,
        onSaved: () => ref.invalidate(_evaluationsProvider(driverId)),
      ),
    );
  }
}

class _EvalCard extends ConsumerWidget {
  final Map<String, dynamic> ev;
  final String driverId;
  final bool showDelete;
  final VoidCallback? onDeleted;
  const _EvalCard({required this.ev, required this.driverId, required this.showDelete, this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating      = (ev['rating'] as num?)?.toDouble() ?? 0;
    final punctuality = ev['punctuality'] as num?;
    final safety      = ev['safety'] as num?;
    final service     = ev['service'] as num?;
    final comment     = ev['comment'] as String?;
    final createdAt   = ev['createdAt'] as String?;
    final evaluatedBy = ev['evaluatedBy'] as Map<String, dynamic>?;
    final trip        = ev['trip'] as Map<String, dynamic>?;
    final route       = trip?['route'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _starRow(rating, size: 16),
          const SizedBox(width: 6),
          Text(rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark)),
          if (route != null) ...[
            const SizedBox(width: 8),
            const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
            const SizedBox(width: 8),
            Expanded(child: Text('${route['origin']} → ${route['destination']}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis)),
          ] else
            const Spacer(),
          if (showDelete)
            GestureDetector(
              onTap: () => _delete(ev['id'] as String, ref, context),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFCBD5E1)),
            ),
        ]),
        if (punctuality != null || safety != null || service != null) ...[
          const SizedBox(height: 10),
          if (punctuality != null) _subScore('Ponctualité', punctuality),
          if (punctuality != null) const SizedBox(height: 6),
          if (safety != null) _subScore('Sécurité', safety),
          if (safety != null) const SizedBox(height: 6),
          if (service != null) _subScore('Service', service),
        ],
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('"$comment"',
              style: const TextStyle(fontSize: 13, color: brandDark, fontStyle: FontStyle.italic)),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (evaluatedBy != null)
            Text('Par ${evaluatedBy['firstName']} ${evaluatedBy['lastName']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const Spacer(),
          Text(_fmtDateFull(createdAt),
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ]),
    );
  }

  Future<void> _delete(String evalId, WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Supprimer l'évaluation ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/drivers/$driverId/evaluations/$evalId');
      onDeleted?.call();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ── Add Absence sheet ──────────────────────────────────────────────────────────

class _AddAbsenceSheet extends StatefulWidget {
  final String driverId;
  final VoidCallback onSaved;
  const _AddAbsenceSheet({required this.driverId, required this.onSaved});

  @override
  State<_AddAbsenceSheet> createState() => _AddAbsenceSheetState();
}

class _AddAbsenceSheetState extends State<_AddAbsenceSheet> {
  String _type = 'LEAVE';
  DateTime? _start, _end;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() { if (isStart) _start = picked; else _end = picked; });
  }

  Future<void> _submit(WidgetRef ref) async {
    if (_start == null || _end == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/drivers/${widget.driverId}/absences', data: {
        'startDate': _start!.toIso8601String(),
        'endDate':   _end!.toIso8601String(),
        'type':      _type,
        'reason':    _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Déclarer une absence',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
          const SizedBox(height: 20),

          // Type
          Row(children: [
            for (final entry in {'LEAVE': 'Congé', 'SICK': 'Maladie', 'OTHER': 'Autre'}.entries)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() => _type = entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == entry.key ? brandOrange : Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _type == entry.key ? brandOrange : Color(0xFFE2E8F0)),
                    ),
                    child: Center(child: Text(entry.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: _type == entry.key ? Colors.white : const Color(0xFF475569),
                      ))),
                  ),
                ),
              )),
          ]),
          const SizedBox(height: 16),

          // Dates
          Row(children: [
            Expanded(child: _DateField(
              label: 'Date début',
              value: _start,
              onTap: () => _pickDate(true),
            )),
            const SizedBox(width: 12),
            Expanded(child: _DateField(
              label: 'Date fin',
              value: _end,
              onTap: () => _pickDate(false),
            )),
          ]),
          const SizedBox(height: 14),

          // Reason
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              labelText: 'Motif (optionnel)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity, height: 48,
            child: FilledButton(
              onPressed: (_start == null || _end == null || _loading) ? null : () => _submit(ref),
              style: FilledButton.styleFrom(
                backgroundColor: brandOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    ));
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value != null ? _fmtDateFull(value!.toIso8601String()) : 'Sélectionner',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: value != null ? brandDark : const Color(0xFF94A3B8))),
      ]),
    ),
  );
}

// ── Add Evaluation sheet ───────────────────────────────────────────────────────

class _AddEvaluationSheet extends StatefulWidget {
  final String driverId;
  final VoidCallback onSaved;
  const _AddEvaluationSheet({required this.driverId, required this.onSaved});

  @override
  State<_AddEvaluationSheet> createState() => _AddEvaluationSheetState();
}

class _AddEvaluationSheetState extends State<_AddEvaluationSheet> {
  int _rating = 4, _punctuality = 4, _safety = 4, _service = 4;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Widget _ratingRow(String label, int value, ValueChanged<int> onChange) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)))),
      Row(children: List.generate(5, (i) => GestureDetector(
        onTap: () => onChange(i + 1),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            i < value ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 26,
            color: i < value ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          ),
        ),
      ))),
    ]);
  }

  Future<void> _submit(WidgetRef ref) async {
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/drivers/${widget.driverId}/evaluations', data: {
        'rating': _rating,
        'punctuality': _punctuality,
        'safety': _safety,
        'service': _service,
        'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Évaluer le chauffeur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
          const SizedBox(height: 20),

          _ratingRow('Note globale *', _rating, (v) => setState(() => _rating = v)),
          const SizedBox(height: 12),
          _ratingRow('Ponctualité', _punctuality, (v) => setState(() => _punctuality = v)),
          const SizedBox(height: 12),
          _ratingRow('Sécurité', _safety, (v) => setState(() => _safety = v)),
          const SizedBox(height: 12),
          _ratingRow('Service', _service, (v) => setState(() => _service = v)),
          const SizedBox(height: 16),

          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Commentaire (optionnel)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity, height: 48,
            child: FilledButton(
              onPressed: _loading ? null : () => _submit(ref),
              style: FilledButton.styleFrom(
                backgroundColor: brandOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    ));
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(height: 240, color: const Color(0xFFF97316).withValues(alpha: 0.3)),
    Expanded(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: List.generate(4, (_) => Container(
        height: 80, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
      ))),
    )),
  ]);
}
