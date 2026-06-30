import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _stationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/stations/$id/info');
      final data = extractData(res.data);
      return Map<String, dynamic>.from(data as Map);
    });

// ── Screen ────────────────────────────────────────────────────────────────────

class StationDetailScreen extends ConsumerWidget {
  final String stationId;
  const StationDetailScreen({super.key, required this.stationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_stationProvider(stationId));
    final favs = ref.watch(favoritesProvider);

    return Scaffold(
      body: async.when(
        loading: () => AppShimmer.listTiles(count: 3),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                l10n.stationCannotLoad,
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_stationProvider(stationId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (station) {
          final id = station['id'] as String? ?? '';
          final isFav = favs.isStationFavorite(id);
          return _StationBody(
            station: station,
            isFavorite: isFav,
            onFavoriteToggle: () =>
                ref.read(favoritesProvider.notifier).toggleStation(station),
          );
        },
      ),
    );
  }
}

class _StationBody extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  const _StationBody({
    required this.station,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  Future<void> _openMap(double? lat, double? lng, String name) async {
    if (lat == null || lng == null) return;
    final encoded = Uri.encodeComponent(name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encoded',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final tenant = station['tenant'] as Map?;
    final city = station['city'] as Map?;
    final upcoming = (station['upcomingDepartures'] as List?) ?? [];
    final total = station['totalDepartures'] as int? ?? 0;
    final double? lat = (station['latitude'] as num?)?.toDouble();
    final double? lng = (station['longitude'] as num?)?.toDouble();
    final fmt = DateFormat('HH:mm', locale);
    final fmtDate = DateFormat('EEE d MMM', locale);

    return CustomScrollView(
      slivers: [
        // ── Hero app bar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: const Color(0xFF0F4C75),
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
                  colors: [Color(0xFF0F4C75), Color(0xFF1B6CA8)],
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
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_city_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station['name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (station['code'] != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      station['code'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _StatChip(
                            label: l10n.stationDeparturesLabel,
                            value: '$total',
                            icon: Icons.departure_board,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: l10n.tripsToday,
                            value: '${upcoming.length}',
                            icon: Icons.today,
                          ),
                          if (lat != null && lng != null) ...[
                            const SizedBox(width: 8),
                            _StatChip(
                              label: 'GPS',
                              value: l10n.stationGpsAvail,
                              icon: Icons.gps_fixed,
                            ),
                          ],
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
                // ── Infos pratiques ────────────────────────────────────────────
                _Section(
                  title: l10n.stationPracticalInfo,
                  child: Column(
                    children: [
                      if (city?['name'] != null)
                        _InfoTile(
                          icon: Icons.location_city_outlined,
                          label:
                              city!['name'] +
                              (city['region'] != null
                                  ? ', ${city['region']}'
                                  : ''),
                        ),
                      if (station['address'] != null)
                        _InfoTile(
                          icon: Icons.map_outlined,
                          label: station['address'],
                        ),
                      if (station['phone'] != null)
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: station['phone'],
                        ),
                      if (tenant != null) ...[
                        const Divider(height: 14),
                        InkWell(
                          onTap: tenant['slug'] != null
                              ? () => context.push(
                                  '/passenger/company/${tenant['slug']}',
                                )
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CompanyLogo.tile(
                                  logo: tenant['logo'] as String?,
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.profileCompany,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.textMuted,
                                        ),
                                      ),
                                      Text(
                                        tenant['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (tenant['slug'] != null)
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: context.textMuted,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Boutons GPS ───────────────────────────────────────────────
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push(
                            '/passenger/navigate-to-station',
                            extra: {
                              'name': station['name'] ?? '',
                              'lat': lat,
                              'lng': lng,
                            },
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: Text(
                            l10n.stationNavigateBtn,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: brandOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openMap(lat, lng, station['name'] ?? ''),
                          icon: Icon(
                            Icons.map_outlined,
                            color: brandOrange,
                            size: 18,
                          ),
                          label: Text(
                            'Google Maps',
                            style: TextStyle(
                              color: brandOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: brandOrange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ),
                ],

                // ── Prochains départs ─────────────────────────────────────────
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: l10n.stationNextDepartures(upcoming.length),
                    child: Column(
                      children: upcoming.asMap().entries.map<Widget>((e) {
                        final i = e.key;
                        final t = Map<String, dynamic>.from(e.value as Map);
                        final dep = DateTime.parse(t['departureAt']).toLocal();
                        final origin = t['route']?['originCity']?['name'] ?? '';
                        final dest =
                            t['route']?['destinationCity']?['name'] ?? '';
                        final price = (t['price'] as num?)?.toInt() ?? 0;
                        final seats = t['availableSeats'] as int? ?? 0;
                        final cls = t['tripClass'] as String? ?? 'STANDARD';
                        return Column(
                          children: [
                            if (i > 0) const Divider(height: 12),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fmt.format(dep),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      fmtDate.format(dep),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$origin → $dest',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          _ClassBadge(cls),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.event_seat_outlined,
                                            size: 11,
                                            color: context.textMuted,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            l10n.stationSeats(seats),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###', locale).format(price)} F',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: brandOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.divider),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.departure_board_outlined,
                          size: 36,
                          color: context.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.stationNoDepartures,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

// ── Shared widgets ────────────────────────────────────────────────────────────

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

class _ClassBadge extends StatelessWidget {
  final String cls;
  const _ClassBadge(this.cls);

  Color get _bg => cls == 'VIP'
      ? const Color(0xFFFEF3C7)
      : cls == 'EXPRESS'
      ? const Color(0xFFEDE9FE)
      : const Color(0xFFF0FDF4);
  Color get _fg => cls == 'VIP'
      ? const Color(0xFFD97706)
      : cls == 'EXPRESS'
      ? const Color(0xFF7C3AED)
      : const Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      cls,
      style: TextStyle(color: _fg, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}
