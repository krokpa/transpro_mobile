import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/widgets/user_avatar.dart';
import 'passenger_shell.dart' show PassengerShellScope;
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/fade_slide.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/providers/favorites_provider.dart';
import '../../l10n/app_localizations.dart';

final _citiesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cities');
  final items = extractData(res.data);
  return (items as List).map((e) => City.fromJson(e)).toList();
});

final _popularDestinationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/trips/popular',
        queryParameters: {'limit': 8},
      );
      final items = extractData(res.data) as List;
      return items.map((e) => e as Map<String, dynamic>).toList();
    });

final _promotionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/promotions/active');
      final items = extractData(res.data) as List;
      return items.map((e) => e as Map<String, dynamic>).toList();
    });

final _partnersProvider = FutureProvider.autoDispose<List<Tenant>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/public');
  final items = extractData(res.data) as List;
  return items.map((e) => Tenant.fromJson(e)).toList();
});

final _upcomingTripsProvider = FutureProvider.autoDispose<List<Trip>>((
  ref,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/upcoming', queryParameters: {'limit': 10});
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

final _nextBookingProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/bookings/my');
  final items = extractData(res.data) as List;
  final now = DateTime.now();
  final upcoming = items.map((e) => e as Map<String, dynamic>).where((b) {
    final status = b['status'] as String?;
    final depAt = b['trip']?['departureAt'] as String?;
    if (status == null || depAt == null) return false;
    final dep = DateTime.tryParse(depAt);
    return (status == 'CONFIRMED' || status == 'PENDING') &&
        dep != null &&
        dep.isAfter(now);
  }).toList();
  upcoming.sort((a, b) {
    final da = DateTime.parse(a['trip']['departureAt'] as String);
    final db = DateTime.parse(b['trip']['departureAt'] as String);
    return da.compareTo(db);
  });
  return upcoming.isEmpty ? null : upcoming.first;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ── État du hero de recherche structurée ────────────────────────────────────
  City? _origin;
  City? _dest;
  DateTime _date = DateTime.now();
  int _passengers = 1;
  Tenant? _company;

  void _swap() => setState(() {
    final tmp = _origin;
    _origin = _dest;
    _dest = tmp;
  });

  Future<void> _refresh() async {
    ref.invalidate(_upcomingTripsProvider);
    ref.invalidate(_nextBookingProvider);
    ref.invalidate(_citiesProvider);
    ref.invalidate(_popularDestinationsProvider);
    ref.invalidate(_promotionsProvider);
    ref.invalidate(_partnersProvider);
    await ref.read(_upcomingTripsProvider.future);
  }

  Future<void> _pickCity({required bool isOrigin}) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        title: isOrigin ? l10n.searchFromCity : l10n.searchToCity,
        hint: isOrigin ? l10n.searchOriginHint : l10n.searchDestHint,
      ),
    );
    if (selected != null) {
      setState(() => isOrigin ? _origin = selected : _dest = selected);
    }
  }

  Future<void> _pickCompany() async {
    final result = await showModalBottomSheet<_CompanyChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyPickerSheet(selected: _company),
    );
    if (result != null) setState(() => _company = result.tenant);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: context.spacePrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPassengers() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PassengerSheet(initial: _passengers),
    );
    if (result != null) setState(() => _passengers = result);
  }

  void _onSearch() {
    final l10n = AppLocalizations.of(context);
    if (_origin == null || _dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchMissingFields)),
      );
      return;
    }
    final uri = Uri(
      path: '/passenger/search',
      queryParameters: {
        'origin': _origin!.name,
        'destination': _dest!.name,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'passengers': '$_passengers',
        if (_company?.slug != null) 'company': _company!.slug!,
      },
    );
    context.go(uri.toString());
  }

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.homeGreetingMorning;
    if (h < 18) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    final tripsAsync = ref.watch(_upcomingTripsProvider);
    final nextBookingAsync = ref.watch(_nextBookingProvider);
    final favs = ref.watch(favoritesProvider);
    // Précharge la liste des villes pour que le sélecteur soit instantané.
    ref.watch(_citiesProvider);
    final fmt = DateFormat(
      'EEE d MMM',
      Localizations.localeOf(context).toString(),
    );

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: RefreshIndicator(
        color: context.spacePrimary,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // ── HERO : header compact + recherche structurée ──────────────────
            SliverToBoxAdapter(
              child: _HomeHero(
                greeting: _greeting(l10n),
                firstName: user.firstName,
                lastName: user.lastName,
                avatar: user.avatar,
                origin: _origin,
                dest: _dest,
                date: _date,
                passengers: _passengers,
                company: _company,
                onMenu: () => PassengerShellScope.of(context)?.openDrawer(),
                onAvatar: () => context.go('/passenger/profile'),
                onPickOrigin: () => _pickCity(isOrigin: true),
                onPickDest: () => _pickCity(isOrigin: false),
                onSwap: _swap,
                onPickDate: _pickDate,
                onPickPassengers: _pickPassengers,
                onPickCompany: _pickCompany,
                onSearch: _onSearch,
                l10n: l10n,
              ),
            ),

            nextBookingAsync.when(
            loading: () => SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Shimmer(child: const ShimmerBookingCard()),
            )),
            error: (_, _) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (booking) => booking == null
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, left: 2),
                              child: Text(
                                l10n.homeNextTripTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            _NextBookingCard(booking: booking, l10n: l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 0),
                      child: _QuickAction(
                        icon: Icons.add_circle_outline_rounded,
                        label: l10n.homeBookNow,
                        color: context.spacePrimary,
                        bg: context.spaceLight,
                        onTap: () => context.go('/passenger/search'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 70),
                      child: _QuickAction(
                        icon: Icons.confirmation_num_outlined,
                        label: l10n.navTickets,
                        color: const Color(0xFF6366F1),
                        bg: const Color(0xFFEEF2FF),
                        onTap: () => context.go('/passenger/bookings'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: _QuickAction(
                        icon: Icons.receipt_long_outlined,
                        label: l10n.homeHistory,
                        color: const Color(0xFF10B981),
                        bg: const Color(0xFFECFDF5),
                        onTap: () => context.push('/passenger/transactions'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 210),
                      child: _QuickAction(
                        icon: Icons.favorite_border_rounded,
                        label: l10n.favoritesTitle,
                        color: const Color(0xFFF43F5E),
                        bg: const Color(0xFFFFE4E6),
                        onTap: () => context.push('/passenger/favorites'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Favorite companies ────────────────────────────────────────────
          if (favs.companies.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.homeFavoriteCompanies,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              context.push('/passenger/favorites'),
                          child: Text(
                            l10n.seeAll,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favs.companies.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final c = favs.companies[i];
                          final logo = c['logo'] as String?;
                          final name = c['name'] as String? ?? '';
                          return GestureDetector(
                            onTap: () => context.push(
                              '/passenger/company/${c['slug']}',
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CompanyLogo.tile(logo: logo, size: 52),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.homeUpcomingDepartures,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/passenger/search'),
                        child: Text(
                          l10n.seeAll,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  tripsAsync.when(
                    loading: () => Shimmer(child: Column(children: List.generate(2, (_) => const ShimmerTripCard()))),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                    data: (trips) {
                      if (trips.isEmpty) return _EmptyState(l10n: l10n);
                      // N'afficher que les 2 premiers — « Voir tout » mène à la recherche.
                      final shown = trips.take(2).toList();
                      return Column(
                        children: [
                          for (int i = 0; i < shown.length; i++)
                            FadeSlideIn(
                              delay: Duration(milliseconds: (i * 70).clamp(0, 280)),
                              child: _TripCard(trip: shown[i], fmt: fmt, l10n: l10n),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Destinations populaires ──────────────────────────────────────
          const SliverToBoxAdapter(child: _PopularDestinations()),
          // ── Promotions / actualités ──────────────────────────────────────
          const SliverToBoxAdapter(child: _PromoBanner()),
          // ── Compagnies partenaires ───────────────────────────────────────
          const SliverToBoxAdapter(child: _PartnersStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _NextBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final AppLocalizations l10n;
  const _NextBookingCard({required this.booking, required this.l10n});

  @override
  State<_NextBookingCard> createState() => _NextBookingCardState();
}

class _NextBookingCardState extends State<_NextBookingCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le compte à rebours chaque minute.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _countdown(DateTime dep) {
    final l10n = widget.l10n;
    final diff = dep.difference(DateTime.now());
    if (diff.inMinutes < 1) return l10n.homeDepartingNow;
    if (diff.inDays >= 1) return l10n.homeDepartsInDays(diff.inDays);
    if (diff.inHours >= 1) {
      return l10n.homeDepartsInHM(diff.inHours, diff.inMinutes % 60);
    }
    return l10n.homeDepartsInMin(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final l10n = widget.l10n;
    final locale = Localizations.localeOf(context).toString();
    final trip = booking['trip'] as Map<String, dynamic>?;
    final origin = trip?['route']?['originCity']?['name'] as String? ?? '';
    final dest = trip?['route']?['destinationCity']?['name'] as String? ?? '';
    final depAtStr = trip?['departureAt'] as String?;
    final depAt = depAtStr != null
        ? DateTime.tryParse(depAtStr)?.toLocal()
        : null;
    final dateFmt = depAt != null
        ? DateFormat('EEE d MMM', locale).format(depAt)
        : '—';
    final timeFmt = depAt != null ? DateFormat('HH:mm').format(depAt) : '—';
    final bookingId = booking['id'] as String;
    final status = booking['status'] as String? ?? 'PENDING';
    final amount = (booking['totalAmount'] as num?)?.toDouble() ?? 0;
    final isConfirmed = status == 'CONFIRMED';

    final accent = isConfirmed
        ? const Color(0xFF10B981) // emerald — confirmé
        : const Color(0xFFF59E0B); // amber — en attente

    return GestureDetector(
      onTap: () => context.push('/passenger/booking/$bookingId'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0C1425), Color(0xFF13314F), Color(0xFF0E5C8C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C1425).withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Cercle décoratif
            Positioned(
              top: -28,
              right: -18,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ligne statut + compte à rebours ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 7, color: accent),
                            const SizedBox(width: 5),
                            Text(
                              isConfirmed
                                  ? l10n.homeNextDeparture
                                  : l10n.homeAwaitingPayment,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (depAt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _countdown(depAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Trajet ──
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          origin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.directions_bus_rounded,
                          color: brandOrange,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          dest,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$dateFmt · $timeFmt',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Séparateur perforé (effet ticket) ──
                  const _DashedLine(),
                  const SizedBox(height: 12),
                  // ── Prix + CTA ──
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${amount.toStringAsFixed(0)} F',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: brandOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.homeViewTickets,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne pointillée horizontale (effet billet déchirable).
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const dashW = 5.0;
      const gap = 4.0;
      final count = (constraints.maxWidth / (dashW + gap)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          count,
          (_) => Container(
            width: dashW,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      );
    },
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Material(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final DateFormat fmt;
  final AppLocalizations l10n;
  const _TripCard({required this.trip, required this.fmt, required this.l10n});

  static const _classCfg = {
    'VIP': (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'EXPRESS': (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.originCity} → ${trip.destinationCity}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (trip.departureStationName != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: context.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  trip.departureStationName!,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (trip.departureStationName != null)
                          const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: context.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fmt.format(trip.departureAt.toLocal()),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (trip.tenantName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              CompanyLogo(logo: trip.tenantLogo, size: 16),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  trip.tenantName!,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.price.toStringAsFixed(0)} F',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: brandOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cc.$1,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trip.tripClass,
                          style: TextStyle(
                            color: cc.$2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.event_seat_outlined,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.availableSeats} ${l10n.searchSeat(trip.availableSeats)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (isBoarding)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.homeBoardingStatus,
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: brandOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.homeBookNow,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.inputFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_bus_outlined,
              size: 34,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.homeNoTripsTitle,
            style: TextStyle(
              color: context.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.homeNoTripsSub,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
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
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFDC2626)),
          ),
        ),
      ],
    ),
  );
}

// ── Hero : header compact + recherche structurée ──────────────────────────────
class _HomeHero extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String lastName;
  final String? avatar;
  final City? origin;
  final City? dest;
  final DateTime date;
  final int passengers;
  final Tenant? company;
  final VoidCallback onMenu;
  final VoidCallback onAvatar;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDest;
  final VoidCallback onSwap;
  final VoidCallback onPickDate;
  final VoidCallback onPickPassengers;
  final VoidCallback onPickCompany;
  final VoidCallback onSearch;
  final AppLocalizations l10n;

  const _HomeHero({
    required this.greeting,
    required this.firstName,
    required this.lastName,
    required this.avatar,
    required this.origin,
    required this.dest,
    required this.date,
    required this.passengers,
    required this.company,
    required this.onMenu,
    required this.onAvatar,
    required this.onPickOrigin,
    required this.onPickDest,
    required this.onSwap,
    required this.onPickDate,
    required this.onPickPassengers,
    required this.onPickCompany,
    required this.onSearch,
    required this.l10n,
  });

  Widget _circle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final primary = context.spacePrimary;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandCanvas, const Color(0xFF0E2A47), primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -30, child: _circle(150, 0.06)),
          Positioned(bottom: -10, left: -25, child: _circle(90, 0.05)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──
                  Row(
                    children: [
                      _HeroIconButton(icon: Icons.menu_rounded, onTap: onMenu),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$firstName 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(
                        notificationsRoute: '/passenger/notifications',
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onAvatar,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: UserAvatarWidget(
                            firstName: firstName,
                            lastName: lastName,
                            avatar: avatar,
                            size: 38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.homeWhereToGo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Carte recherche structurée ──
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: brandCanvas.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Column(
                              children: [
                                _HeroField(
                                  icon: Icons.trip_origin_rounded,
                                  iconColor: primary,
                                  label: l10n.searchFromCity,
                                  value: origin?.name,
                                  hint: l10n.searchOriginHint,
                                  onTap: onPickOrigin,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 52),
                                  child: Divider(height: 1, color: context.divider),
                                ),
                                _HeroField(
                                  icon: Icons.location_on_rounded,
                                  iconColor: brandOrange,
                                  label: l10n.searchToCity,
                                  value: dest?.name,
                                  hint: l10n.searchDestHint,
                                  onTap: onPickDest,
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: GestureDetector(
                                onTap: onSwap,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: context.cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.divider),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.swap_vert_rounded,
                                    color: primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _HeroMiniField(
                                icon: Icons.calendar_today_rounded,
                                text: DateFormat('EEE d MMM', locale).format(date),
                                onTap: onPickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _HeroMiniField(
                                icon: Icons.person_rounded,
                                text: '$passengers ${l10n.departurePaxSuffix}',
                                onTap: onPickPassengers,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ── Compagnie de préférence (optionnel) ──
                        _HeroMiniField(
                          icon: Icons.business_rounded,
                          text: company?.name ?? l10n.homeAnyCompany,
                          onTap: onPickCompany,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: onSearch,
                            icon: const Icon(Icons.search_rounded, size: 20),
                            label: Text(l10n.search),
                          ),
                        ),
                      ],
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

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.12),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
  );
}

class _HeroField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  const _HeroField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasValue ? context.textPrimary : context.textMuted,
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMiniField extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _HeroMiniField({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Bottom sheet : sélection d'une ville (avec recherche) ─────────────────────
class _CityPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final String hint;
  const _CityPickerSheet({required this.title, required this.hint});

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final citiesAsync = ref.watch(_citiesProvider);
    final cities = citiesAsync.value ?? const <City>[];
    final filtered = _query.isEmpty
        ? cities
        : cities
              .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: citiesAsync.isLoading && cities.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.spacePrimary,
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        citiesAsync.hasError ? l10n.error : l10n.searchNoResults,
                        style: TextStyle(color: context.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: Icon(
                            Icons.location_city_rounded,
                            color: context.spacePrimary,
                          ),
                          title: Text(
                            c.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet : compagnie de préférence ────────────────────────────────────
/// Wrapper de résultat : tenant == null signifie « Toutes les compagnies ».
class _CompanyChoice {
  final Tenant? tenant;
  const _CompanyChoice(this.tenant);
}

class _CompanyPickerSheet extends ConsumerStatefulWidget {
  final Tenant? selected;
  const _CompanyPickerSheet({required this.selected});

  @override
  ConsumerState<_CompanyPickerSheet> createState() =>
      _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends ConsumerState<_CompanyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final partnersAsync = ref.watch(_partnersProvider);
    final tenants = partnersAsync.value ?? const <Tenant>[];
    final filtered = _query.isEmpty
        ? tenants
        : tenants
              .where((t) => t.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.searchCompany,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.searchCompany,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: partnersAsync.isLoading && tenants.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.spacePrimary,
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      children: [
                        // Option « Toutes les compagnies »
                        ListTile(
                          leading: Icon(
                            Icons.apps_rounded,
                            color: context.spacePrimary,
                          ),
                          title: Text(
                            l10n.homeAnyCompany,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: widget.selected == null
                              ? Icon(Icons.check_rounded,
                                  color: context.spacePrimary)
                              : null,
                          onTap: () =>
                              Navigator.of(context).pop(const _CompanyChoice(null)),
                        ),
                        for (final t in filtered)
                          ListTile(
                            leading: CompanyLogo(logo: t.logo, size: 32),
                            title: Text(
                              t.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: widget.selected?.id == t.id
                                ? Icon(Icons.check_rounded,
                                    color: context.spacePrimary)
                                : null,
                            onTap: () =>
                                Navigator.of(context).pop(_CompanyChoice(t)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet : nombre de passagers ────────────────────────────────────────
class _PassengerSheet extends StatefulWidget {
  final int initial;
  const _PassengerSheet({required this.initial});

  @override
  State<_PassengerSheet> createState() => _PassengerSheetState();
}

class _PassengerSheetState extends State<_PassengerSheet> {
  late int _count = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.searchPassengerCount,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: _count > 1 ? () => setState(() => _count--) : null,
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '$_count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: _count < 9 ? () => setState(() => _count++) : null,
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_count),
                child: Text(l10n.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? context.spaceLight : context.inputFill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            size: 24,
            color: enabled ? context.spacePrimary : context.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Petit en-tête de section réutilisable ─────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: context.textPrimary,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(
          subtitle!,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ],
    ],
  );
}

// ── Destinations populaires (carrousel) ───────────────────────────────────────
class _PopularDestinations extends ConsumerWidget {
  const _PopularDestinations();

  static const _gradients = [
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    [Color(0xFF6366F1), Color(0xFF4338CA)],
    [Color(0xFF10B981), Color(0xFF047857)],
    [Color(0xFFF97316), Color(0xFFC2410C)],
    [Color(0xFFEC4899), Color(0xFFBE185D)],
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_popularDestinationsProvider);
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 0, 0),
        child: Shimmer(
          child: SizedBox(
            height: 172,
            child: Row(
              children: List.generate(
                3,
                (_) => Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: context.inputFill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionHeader(title: l10n.homePopularDestinations),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => FadeSlideIn(
                    delay: Duration(milliseconds: (i * 60).clamp(0, 300)),
                    child: _DestinationCard(
                      data: items[i],
                      gradient: _gradients[i % _gradients.length],
                      l10n: l10n,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Color> gradient;
  final AppLocalizations l10n;
  const _DestinationCard({
    required this.data,
    required this.gradient,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final dest = data['destination'] as String? ?? '';
    final region = data['region'] as String?;
    final fromPrice = (data['fromPrice'] as num?)?.toDouble() ?? 0;
    final tripCount = (data['tripCount'] as num?)?.toInt() ?? 0;
    final origins = (data['origins'] as List?)?.cast<String>() ?? const [];

    return GestureDetector(
      onTap: () {
        final q = <String, String>{'destination': dest};
        if (origins.isNotEmpty) q['origin'] = origins.first;
        q['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        context.go(Uri(path: '/passenger/search', queryParameters: q).toString());
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                Icons.location_city_rounded,
                size: 96,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      l10n.homeTripsAvailable(tripCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (region != null && region.isNotEmpty)
                    Text(
                      region,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeFromPrice(fromPrice.toStringAsFixed(0)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bannière promotions / actualités (carrousel auto) ─────────────────────────
class _PromoBanner extends ConsumerStatefulWidget {
  const _PromoBanner();

  @override
  ConsumerState<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends ConsumerState<_PromoBanner> {
  final _controller = PageController();
  Timer? _autoplay;
  int _page = 0;

  void _startAutoplay(int count) {
    _autoplay?.cancel();
    if (count <= 1) return;
    _autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % count;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _accent(Map<String, dynamic> p) {
    final hex = p['color'] as String?;
    if (hex != null && hex.startsWith('#') && hex.length >= 7) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
    switch (p['type'] as String?) {
      case 'ALERT':
        return const Color(0xFFDC2626);
      case 'NEWS':
        return const Color(0xFF6366F1);
      default:
        return brandOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_promotionsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (promos) {
        if (promos.isEmpty) return const SizedBox.shrink();
        _startAutoplay(promos.length);
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              SizedBox(
                height: 104,
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: promos.length,
                  itemBuilder: (context, i) =>
                      _PromoCard(promo: promos[i], accent: _accent(promos[i])),
                ),
              ),
              if (promos.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    promos.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? context.spacePrimary
                            : context.divider,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final Color accent;
  const _PromoCard({required this.promo, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = promo['title'] as String? ?? '';
    final subtitle = promo['subtitle'] as String?;
    final code = promo['code'] as String?;
    final ctaUrl = promo['ctaUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: ctaUrl != null && ctaUrl.startsWith('/')
            ? () => context.push(ctaUrl)
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.black, 0.30)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  promo['type'] == 'ALERT'
                      ? Icons.campaign_rounded
                      : promo['type'] == 'NEWS'
                      ? Icons.article_rounded
                      : Icons.local_offer_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (code != null && code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bandeau compagnies partenaires (réassurance) ──────────────────────────────
class _PartnersStrip extends ConsumerWidget {
  const _PartnersStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_partnersProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tenants) {
        if (tenants.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionHeader(
                  title: l10n.homePartners,
                  subtitle: l10n.homePartnersCount(tenants.length),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tenants.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final t = tenants[i];
                    return GestureDetector(
                      onTap: t.slug != null
                          ? () => context.push('/passenger/company/${t.slug}')
                          : null,
                      child: SizedBox(
                        width: 64,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompanyLogo.tile(logo: t.logo, size: 52),
                            const SizedBox(height: 4),
                            Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
