import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _companyProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, slug) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/tenants/slug/$slug');
      final data = extractData(res.data);
      return Map<String, dynamic>.from(data as Map);
    });

// ── Screen ────────────────────────────────────────────────────────────────────

class CompanyDetailScreen extends ConsumerWidget {
  final String slug;
  const CompanyDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_companyProvider(slug));
    final favs = ref.watch(favoritesProvider);

    return Scaffold(
      body: async.when(
        loading: () => AppShimmer.listTiles(count: 4),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                l10n.companyCannotLoad,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_companyProvider(slug)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (company) {
          final id = company['id'] as String? ?? '';
          final isFav = favs.isCompanyFavorite(id);
          return _CompanyBody(
            company: company,
            isFavorite: isFav,
            onFavoriteToggle: () =>
                ref.read(favoritesProvider.notifier).toggleCompany(company),
          );
        },
      ),
    );
  }
}

class _CompanyBody extends StatelessWidget {
  final Map<String, dynamic> company;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  const _CompanyBody({
    required this.company,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stations = (company['stations'] as List?) ?? [];
    final routes = (company['routes'] as List?) ?? [];
    final count = company['_count'] as Map?;
    final upcoming = company['upcomingTrips'] as int? ?? 0;

    return CustomScrollView(
      slivers: [
        // ── Hero app bar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: brandCanvas,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? const Color(0xFFF59E0B) : Colors.white70,
              ),
              onPressed: onFavoriteToggle,
            ),
          ],
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
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CompanyLogo.onDark(logo: company['logo'] as String?, size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company['name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (company['city']?['name'] != null)
                                  Text(
                                    company['city']['name'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatChip(
                            label: l10n.companyTripsAvail,
                            value: '$upcoming',
                            icon: Icons.departure_board,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: l10n.stationsTitle,
                            value: '${count?['stations'] ?? stations.length}',
                            icon: Icons.location_city,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: l10n.companyLinesLabel,
                            value: '${count?['routes'] ?? routes.length}',
                            icon: Icons.alt_route,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Contact ────────────────────────────────────────────────────
                _Section(
                  title: l10n.companyContact,
                  child: Column(
                    children: [
                      if (company['phone'] != null)
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: company['phone'],
                        ),
                      if (company['email'] != null)
                        _InfoTile(
                          icon: Icons.email_outlined,
                          label: company['email'],
                        ),
                      if (company['address'] != null)
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: company['address'],
                        ),
                    ],
                  ),
                ),

                // ── Stations ──────────────────────────────────────────────────
                if (stations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.companyStationsCount(stations.length),
                    child: Column(
                      children: stations
                          .map<Widget>(
                            (s) => _StationTile(
                              station: Map<String, dynamic>.from(s as Map),
                              onTap: () =>
                                  context.push('/passenger/station/${s['id']}'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],

                // ── Routes ────────────────────────────────────────────────────
                if (routes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.companyRoutesCount(routes.length),
                    child: Column(
                      children: routes.map<Widget>((r) {
                        final origin = r['originCity']?['name'] ?? '';
                        final dest = r['destinationCity']?['name'] ?? '';
                        final dur = r['durationMinutes'] as int?;
                        final price = (r['basePrice'] as num?)?.toInt();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.route_outlined,
                                size: 16,
                                color: context.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$origin → $dest',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    if (dur != null)
                                      Text(
                                        '${dur ~/ 60}h${(dur % 60).toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (price != null && price > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brandOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$price F',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: brandOrange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.divider),
        ),
        child: child,
      ),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _StationTile extends StatelessWidget {
  final Map<String, dynamic> station;
  final VoidCallback onTap;
  const _StationTile({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brandOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_city_outlined,
              size: 18,
              color: brandOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station['name'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                if (station['city']?['name'] != null ||
                    station['address'] != null)
                  Text(
                    [
                      station['city']?['name'],
                      station['address'],
                    ].whereType<String>().join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: context.textMuted),
        ],
      ),
    ),
  );
}
