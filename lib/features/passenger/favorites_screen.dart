import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/favorites_provider.dart';
import '../../l10n/app_localizations.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favs = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(l10n.favoritesTitle),
        backgroundColor: brandCanvas,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Companies ────────────────────────────────────────────────────
            Text(
              l10n.favoritesCompanies,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (favs.companies.isEmpty)
              _EmptyCard(
                message: l10n.favoritesNoCompanies,
                icon: Icons.business_outlined,
                onAction: () => context.push('/passenger/companies'),
                actionLabel: l10n.companiesTitle,
              )
            else
              ...favs.companies.map(
                (c) => _CompanyTile(
                  company: c,
                  onRemove: () =>
                      ref.read(favoritesProvider.notifier).toggleCompany(c),
                  onTap: () =>
                      context.push('/passenger/company/${c['slug']}'),
                ),
              ),

            const SizedBox(height: 24),

            // ── Stations ─────────────────────────────────────────────────────
            Text(
              l10n.favoritesStations,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (favs.stations.isEmpty)
              _EmptyCard(
                message: l10n.favoritesNoStations,
                icon: Icons.location_city_outlined,
              )
            else
              ...favs.stations.map(
                (s) => _StationTile(
                  station: s,
                  onRemove: () =>
                      ref.read(favoritesProvider.notifier).toggleStation(s),
                  onTap: () => context.push('/passenger/station/${s['id']}'),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  const _EmptyCard({
    required this.message,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.divider),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: context.textMuted),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(color: context.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: brandOrange,
              side: const BorderSide(color: brandOrange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _CompanyTile extends StatelessWidget {
  final Map<String, dynamic> company;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _CompanyTile({
    required this.company,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final logo = company['logo'] as String?;
    final name = company['name'] as String? ?? '';
    final cityMap = company['city'];
    final city = cityMap is Map ? cityMap['name'] as String? : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _Logo(logo: logo, size: 40),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        subtitle: city != null
            ? Text(
                city,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          onPressed: onRemove,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final Map<String, dynamic> station;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _StationTile({
    required this.station,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = station['name'] as String? ?? '';
    final cityMap = station['city'];
    final city = cityMap is Map ? cityMap['name'] as String? : null;
    final address = station['address'] as String?;
    final sub =
        [city, address].whereType<String>().join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_city_outlined,
            size: 20,
            color: brandOrange,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        subtitle: sub.isNotEmpty
            ? Text(
                sub,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          onPressed: onRemove,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String? logo;
  final double size;
  const _Logo({this.logo, required this.size});

  @override
  Widget build(BuildContext context) {
    if (logo != null && logo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: brandOrange.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.directions_bus_rounded,
      size: size * 0.45,
      color: brandOrange,
    ),
  );
}
