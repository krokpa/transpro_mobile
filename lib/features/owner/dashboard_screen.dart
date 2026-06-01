import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fade_slide.dart';
import '../../core/widgets/notification_bell.dart';
import '../../l10n/app_localizations.dart';

final _statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/me/stats');
  return extractData(res.data) as Map<String, dynamic>;
});

final _analyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/me/analytics', queryParameters: {'period': period});
  return extractData(res.data) as Map<String, dynamic>;
});

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override
  ConsumerState<OwnerDashboardScreen> createState() => _State();
}

class _State extends ConsumerState<OwnerDashboardScreen> {
  String _period = '7d';

  String _fmtNum(double v) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat('#,###', locale).format(v.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user!;
    final statsAsync = ref.watch(_statsProvider);
    final analyticsAsync = ref.watch(_analyticsProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.dashboardTitle),
          Text(user.fullName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: context.textMuted)),
        ]),
        actions: const [
          NotificationBell(notificationsRoute: '/owner/notifications'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(_analyticsProvider(_period));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            statsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (e, _) => Text('${l10n.error}: $e'),
              data: (stats) => Column(children: [
                Row(children: [
                  Expanded(child: FadeSlideIn(
                    delay: const Duration(milliseconds: 0),
                    child: _KpiCard(
                      label: l10n.dashboardRevenueMonth, icon: Icons.payments_outlined,
                      value: '${_fmtNum((stats['revenueMonth'] as num?)?.toDouble() ?? 0)} F',
                      color: brandOrange, bg: brandLight,
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _KpiCard(
                      label: l10n.dashboardTicketsMonth, icon: Icons.confirmation_num_outlined,
                      value: '${stats['ticketsMonth'] ?? 0}',
                      color: const Color(0xFF6366F1), bg: const Color(0xFFEEF2FF),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _KpiCard(
                      label: l10n.dashboardVehiclesLabel, icon: Icons.directions_bus_outlined,
                      value: '${stats['vehicleCount'] ?? 0}',
                      color: const Color(0xFF0EA5E9), bg: const Color(0xFFE0F2FE),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: _KpiCard(
                      label: l10n.dashboardRoutesLabel, icon: Icons.alt_route,
                      value: '${stats['routeCount'] ?? 0}',
                      color: const Color(0xFF16A34A), bg: const Color(0xFFF0FDF4),
                    ),
                  )),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            Row(children: [
              Text(l10n.dashboardAnalysis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary)),
              const Spacer(),
              _PeriodChip(label: '7d', value: '7d', current: _period, onTap: (v) => setState(() => _period = v)),
              const SizedBox(width: 6),
              _PeriodChip(label: '30d', value: '30d', current: _period, onTap: (v) => setState(() => _period = v)),
              const SizedBox(width: 6),
              _PeriodChip(label: '90d', value: '90d', current: _period, onTap: (v) => setState(() => _period = v)),
            ]),
            const SizedBox(height: 12),

            analyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('${l10n.error}: $e'),
              data: (analytics) {
                final timeline = (analytics['timeline'] as List?) ?? [];
                if (timeline.isEmpty) return Center(
                  child: Text(l10n.dashboardNoData, style: TextStyle(color: context.textMuted)),
                );
                final maxRev = timeline.fold<double>(0, (m, t) {
                  final v = (t['revenue'] as num?)?.toDouble() ?? 0;
                  return v > m ? v : m;
                });
                final locale = Localizations.localeOf(context).toString();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.dashboardDailyRevenue, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textSecondary)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: timeline.take(14).map<Widget>((t) {
                            final rev = (t['revenue'] as num?)?.toDouble() ?? 0;
                            final targetH = (maxRev > 0 ? (rev / maxRev) * 100 : 0.0)
                                .clamp(4.0, 100.0);
                            return Expanded(child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: targetH),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, h, _) => Container(
                                    height: h,
                                    decoration: BoxDecoration(
                                      color: brandOrange,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ]),
                            ));
                          }).toList(),
                        ),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatSmall(
                      label: l10n.dashboardTotalRevenue,
                      value: '${NumberFormat('#,###', locale).format((analytics['totalRevenue'] as num?)?.toInt() ?? 0)} F',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _StatSmall(
                      label: l10n.dashboardTotalTickets,
                      value: '${analytics['totalTickets'] ?? 0}',
                    )),
                  ]),
                  const SizedBox(height: 12),
                  if ((analytics['topRoutes'] as List?)?.isNotEmpty == true) ...[
                    Text(l10n.dashboardTopRoutes,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary)),
                    const SizedBox(height: 8),
                    ...(analytics['topRoutes'] as List).take(5).map((r) => _RouteRow(route: r, locale: locale)),
                  ],
                ]);
              },
            ),
            const SizedBox(height: 24),
            Text(l10n.dashboardManagement,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _MgmtTile(icon: Icons.person_outlined,    label: l10n.dashboardDriversNav,   route: '/owner/drivers'),
                _MgmtTile(icon: Icons.schedule_outlined,  label: l10n.dashboardSchedulesNav, route: '/owner/schedules'),
                _MgmtTile(icon: Icons.group_outlined,     label: l10n.dashboardStaffNav,     route: '/owner/staff'),
                _MgmtTile(icon: Icons.bar_chart_outlined, label: l10n.dashboardReportsNav,   route: '/owner/reports'),
                _MgmtTile(icon: Icons.store_outlined,     label: l10n.dashboardStationsNav,  route: '/owner/stations'),
                _MgmtTile(icon: Icons.alt_route_outlined, label: l10n.dashboardNetworkNav,   route: '/owner/routes'),
              ],
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
    ]),
  ));
}

class _PeriodChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _PeriodChip({required this.label, required this.value, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? brandOrange : context.inputFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : context.textSecondary,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        )),
      ),
    );
  }
}

class _StatSmall extends StatelessWidget {
  final String label, value;
  const _StatSmall({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary)),
    ]),
  ));
}

class _RouteRow extends StatelessWidget {
  final Map<String, dynamic> route;
  final String locale;
  const _RouteRow({required this.route, required this.locale});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.divider),
    ),
    child: Row(children: [
      Expanded(child: Text(route['name'] ?? '—',
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: context.textPrimary))),
      Text('${route['trips'] ?? 0} ${AppLocalizations.of(context).dashboardTripsNav}',
        style: TextStyle(color: context.textMuted, fontSize: 12)),
      const SizedBox(width: 8),
      Text('${NumberFormat('#,###', locale).format((route['revenue'] as num?)?.toInt() ?? 0)} F',
        style: const TextStyle(fontWeight: FontWeight.w600, color: brandOrange, fontSize: 13)),
    ]),
  );
}

class _MgmtTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _MgmtTile({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(route),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: context.tagBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: brandOrange, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textPrimary),
          textAlign: TextAlign.center),
      ]),
    ),
  );
}
