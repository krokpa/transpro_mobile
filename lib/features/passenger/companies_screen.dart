import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

final _companiesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/public');
  final data = extractData(res.data);
  return (data as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_companiesListProvider);
    final favs = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(l10n.companiesTitle),
        backgroundColor: brandCanvas,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.companiesSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => AppShimmer.companyChips(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      l10n.error,
                      style: TextStyle(color: context.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(_companiesListProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (companies) {
                final filtered = _query.isEmpty
                    ? companies
                    : companies.where((c) {
                        final name =
                            (c['name'] as String? ?? '').toLowerCase();
                        final city = (c['city']?['name'] as String? ?? '')
                            .toLowerCase();
                        return name.contains(_query) ||
                            city.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noResults,
                      style: TextStyle(color: context.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final id = c['id'] as String? ?? '';
                    final isFav = favs.isCompanyFavorite(id);
                    return _CompanyCard(
                      company: c,
                      isFavorite: isFav,
                      onFavoriteToggle: () => ref
                          .read(favoritesProvider.notifier)
                          .toggleCompany(c),
                      onTap: () =>
                          context.push('/passenger/company/${c['slug']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _CompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.company,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final logo = company['logo'] as String?;
    final name = company['name'] as String? ?? '';
    final city = company['city']?['name'] as String?;
    final count = company['_count'] as Map?;
    final stations = company['stations'] as List?;
    final upcoming = company['upcomingTrips'] as int? ?? 0;
    final stationCount = (count?['stations'] as int?) ??
        stations?.length ??
        0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.divider),
        ),
        child: Row(
          children: [
            CompanyLogo.tile(logo: logo, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (city != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: context.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniChip(
                        icon: Icons.departure_board,
                        label: '$upcoming',
                        color: brandOrange,
                      ),
                      const SizedBox(width: 6),
                      _MiniChip(
                        icon: Icons.location_city_outlined,
                        label: '$stationCount',
                        color: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onFavoriteToggle,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite
                    ? const Color(0xFFF59E0B)
                    : context.textMuted,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
