import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/branding/branding_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fade_slide.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';
import 'setup_progress_provider.dart';
import 'widgets/setup_banner.dart';

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
    final l10n         = AppLocalizations.of(context);
    final user         = ref.watch(authProvider).user;
    if (user == null || !user.isOwner) return const SizedBox.shrink();
    final statsAsync   = ref.watch(_statsProvider);
    final analyticsAsync = ref.watch(_analyticsProvider(_period));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: brandOrange,
        displacement: 100,
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(_analyticsProvider(_period));
          ref.invalidate(setupProgressProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero ────────────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: ref.watch(brandingProvider).primaryColor,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                ref.watch(brandingProvider).appName,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              actions: const [
                NotificationBell(notificationsRoute: '/owner/notifications'),
                SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _HeroBackground(user: user, statsAsync: statsAsync),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────────
            // ── Setup progress banner ────────────────────────────────────────
            const SliverToBoxAdapter(child: SetupProgressBanner()),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // KPI 2×2
                statsAsync.when(
                  loading: () => Shimmer(child: Column(children: List.generate(2, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: ShimmerListTile())))),
                  error: (e, _) => Text('${l10n.error}: $e'),
                  data: (stats) => Column(children: [
                    Row(children: [
                      Expanded(child: FadeSlideIn(delay: Duration.zero, child: _KpiCard(
                        label: l10n.dashboardRevenueMonth, icon: Icons.payments_outlined,
                        value: '${_fmtNum((stats['revenueMonth'] as num?)?.toDouble() ?? 0)} F',
                        color: brandOrange, bg: brandLight,
                      ))),
                      const SizedBox(width: 12),
                      Expanded(child: FadeSlideIn(delay: const Duration(milliseconds: 80), child: _KpiCard(
                        label: l10n.dashboardTicketsMonth, icon: Icons.confirmation_num_outlined,
                        value: '${stats['ticketsMonth'] ?? 0}',
                        color: const Color(0xFF6366F1), bg: const Color(0xFFEEF2FF),
                      ))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: FadeSlideIn(delay: const Duration(milliseconds: 160), child: _KpiCard(
                        label: l10n.dashboardVehiclesLabel, icon: Icons.directions_bus_outlined,
                        value: '${stats['vehicleCount'] ?? 0}',
                        color: const Color(0xFF0EA5E9), bg: const Color(0xFFE0F2FE),
                      ))),
                      const SizedBox(width: 12),
                      Expanded(child: FadeSlideIn(delay: const Duration(milliseconds: 240), child: _KpiCard(
                        label: l10n.dashboardRoutesLabel, icon: Icons.alt_route,
                        value: '${stats['routeCount'] ?? 0}',
                        color: const Color(0xFF16A34A), bg: const Color(0xFFF0FDF4),
                      ))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 24),

                // Analytics
                _SectionHeader(
                  title: l10n.dashboardAnalysis,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    _PeriodChip(label: '7j',  value: '7d',  current: _period, onTap: (v) => setState(() => _period = v)),
                    const SizedBox(width: 6),
                    _PeriodChip(label: '30j', value: '30d', current: _period, onTap: (v) => setState(() => _period = v)),
                    const SizedBox(width: 6),
                    _PeriodChip(label: '90j', value: '90d', current: _period, onTap: (v) => setState(() => _period = v)),
                  ]),
                ),
                const SizedBox(height: 12),

                analyticsAsync.when(
                  loading: () => Shimmer(child: Column(children: List.generate(2, (_) => const ShimmerTripCard()))),
                  error: (e, _) => Text('${l10n.error}: $e'),
                  data: (analytics) {
                    final timeline = (analytics['timeline'] as List?) ?? [];
                    if (timeline.isEmpty) return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text(l10n.dashboardNoData, style: TextStyle(color: context.textMuted))),
                    );
                    final maxRev = timeline.fold<double>(0, (m, t) {
                      final v = (t['revenue'] as num?)?.toDouble() ?? 0;
                      return v > m ? v : m;
                    });
                    final locale = Localizations.localeOf(context).toString();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Bar chart card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l10n.dashboardDailyRevenue,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textSecondary)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 110,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: timeline.take(14).map<Widget>((t) {
                                final rev = (t['revenue'] as num?)?.toDouble() ?? 0;
                                final targetH = (maxRev > 0 ? (rev / maxRev) * 90 : 0.0).clamp(4.0, 90.0);
                                return Expanded(child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: targetH),
                                      duration: const Duration(milliseconds: 700),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, h, __) => Container(
                                        height: h,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [brandOrange, Color(0xFFFF6B00)],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ));
                              }).toList(),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _StatSmall(
                          label: l10n.dashboardTotalRevenue,
                          value: '${NumberFormat('#,###', locale).format((analytics['totalRevenue'] as num?)?.toInt() ?? 0)} F',
                          icon: Icons.payments_outlined, color: brandOrange,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatSmall(
                          label: l10n.dashboardTotalTickets,
                          value: '${analytics['totalTickets'] ?? 0}',
                          icon: Icons.confirmation_num_outlined, color: const Color(0xFF6366F1),
                        )),
                      ]),
                      if ((analytics['topRoutes'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 20),
                        _SectionHeader(title: l10n.dashboardTopRoutes),
                        const SizedBox(height: 10),
                        ...(analytics['topRoutes'] as List).take(5).map(
                          (r) => _RouteRow(route: r, locale: locale)),
                      ],
                    ]);
                  },
                ),

                const SizedBox(height: 24),

                // Management grid
                _SectionHeader(title: l10n.dashboardManagement),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    _MgmtTile(icon: Icons.person_outlined,    label: l10n.dashboardDriversNav,   route: '/owner/drivers'),
                    _MgmtTile(icon: Icons.schedule_outlined,  label: l10n.dashboardSchedulesNav, route: '/owner/schedules'),
                    _MgmtTile(icon: Icons.group_outlined,     label: l10n.dashboardStaffNav,     route: '/owner/staff'),
                    _MgmtTile(icon: Icons.bar_chart_outlined, label: l10n.dashboardReportsNav,   route: '/owner/reports'),
                    _MgmtTile(icon: Icons.store_outlined,     label: l10n.dashboardStationsNav,  route: '/owner/stations'),
                    _MgmtTile(icon: Icons.alt_route_outlined, label: l10n.dashboardNetworkNav,   route: '/owner/routes'),
                  ],
                ),
                const SizedBox(height: 24),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero background ────────────────────────────────────────────────────────────

class _HeroBackground extends ConsumerWidget {
  final User user;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  const _HeroBackground({required this.user, required this.statsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dégradé piloté par la couleur de marque admin (runtime).
    final brand = ref.watch(brandingProvider).primaryColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(brand, Colors.white, 0.16)!, brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(children: [
                UserAvatarWidget(
                  firstName: user.firstName, lastName: user.lastName,
                  avatar: user.avatar, size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'Bonjour, ${user.firstName} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _roleLabel(user.role),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ])),
              ]),
              const SizedBox(height: 14),
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) {
                  final fmt = NumberFormat.compact(locale: 'fr');
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _StatPill(icon: Icons.payments_outlined,
                        label: '${fmt.format((stats['revenueMonth'] as num?)?.toInt() ?? 0)} F'),
                      const SizedBox(width: 8),
                      _StatPill(icon: Icons.confirmation_num_outlined,
                        label: '${stats['ticketsMonth'] ?? 0} tickets'),
                      const SizedBox(width: 8),
                      _StatPill(icon: Icons.directions_bus_outlined,
                        label: '${stats['vehicleCount'] ?? 0} bus'),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleLabel(String role) => const {
    'COMPANY_OWNER': 'Propriétaire',
    'COMPANY_ADMIN': 'Administrateur',
  }[role] ?? 'Propriétaire';
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 20,
      decoration: BoxDecoration(color: brandOrange, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Expanded(child: Text(title,
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: context.textPrimary))),
    if (trailing != null) trailing!,
  ]);
}

// ── KPI card ───────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
    ]),
  );
}

// ── Period chip ────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

// ── Stat small ─────────────────────────────────────────────────────────────────

class _StatSmall extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatSmall({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 17)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
      ]),
    ]),
  );
}

// ── Route row ──────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final Map<String, dynamic> route;
  final String locale;
  const _RouteRow({required this.route, required this.locale});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.divider),
    ),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: brandOrange, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(route['name'] ?? '—',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimary))),
      Text('${route['trips'] ?? 0} voy.', style: TextStyle(color: context.textMuted, fontSize: 11)),
      const SizedBox(width: 10),
      Text('${NumberFormat('#,###', locale).format((route['revenue'] as num?)?.toInt() ?? 0)} F',
        style: TextStyle(fontWeight: FontWeight.w700, color: brandOrange, fontSize: 13)),
    ]),
  );
}

// ── Management tile ────────────────────────────────────────────────────────────

class _MgmtTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _MgmtTile({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(route),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: brandOrange, size: 22)),
        const SizedBox(height: 8),
        Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textPrimary),
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}
