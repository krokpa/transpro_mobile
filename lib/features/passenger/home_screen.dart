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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    final tripsAsync = ref.watch(_upcomingTripsProvider);
    final nextBookingAsync = ref.watch(_nextBookingProvider);
    final favs = ref.watch(favoritesProvider);
    final fmt = DateFormat(
      'EEE d MMM',
      Localizations.localeOf(context).toString(),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: brandCanvas,
            scrolledUnderElevation: 0,
            // Toolbar visible uniquement en état réduit (scrollé)
            title: const Text(
              'TransPro CI',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => PassengerShellScope.of(ctx)?.openDrawer(),
              ),
            ),
            actions: const [
              NotificationBell(notificationsRoute: '/passenger/notifications'),
              SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              // titlePadding nul : on gère tout dans background
              titlePadding: EdgeInsets.zero,
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
                    // Contenu décalé sous la toolbar (kToolbarHeight) pour éviter le chevauchement
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.go('/passenger/profile'),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 2,
                                      ),
                                    ),
                                    child: UserAvatarWidget(
                                      firstName: user.firstName,
                                      lastName: user.lastName,
                                      avatar: user.avatar,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.homeGreeting(user.firstName),
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                    Text(
                                      l10n.homeWhereToGo,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l10n.homeSearchHint,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
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
                                  ],
                                ),
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _NextBookingCard(booking: booking, l10n: l10n),
                    ),
                  ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 0),
                      child: _QuickAction(
                        icon: Icons.search_rounded,
                        label: l10n.navSearch,
                        color: brandOrange,
                        bg: context.tagBg,
                        onTap: () => context.go('/passenger/search'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
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
                      delay: const Duration(milliseconds: 160),
                      child: _QuickAction(
                        icon: Icons.notifications_outlined,
                        label: l10n.homeAlerts,
                        color: const Color(0xFF0EA5E9),
                        bg: const Color(0xFFE0F2FE),
                        onTap: () => context.push('/passenger/notifications'),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    loading: () => Shimmer(child: Column(children: List.generate(3, (_) => const ShimmerTripCard()))),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                    data: (trips) => trips.isEmpty
                        ? _EmptyState(l10n: l10n)
                        : Column(
                            children: [
                              for (int i = 0; i < trips.length; i++)
                                FadeSlideIn(
                                  delay: Duration(milliseconds: (i * 70).clamp(0, 280)),
                                  child: _TripCard(trip: trips[i], fmt: fmt, l10n: l10n),
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

class _NextBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final AppLocalizations l10n;
  const _NextBookingCard({required this.booking, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final trip = booking['trip'] as Map<String, dynamic>?;
    final origin = trip?['route']?['originCity']?['name'] as String? ?? '';
    final dest = trip?['route']?['destinationCity']?['name'] as String? ?? '';
    final depAtStr = trip?['departureAt'] as String?;
    final depAt = depAtStr != null
        ? DateTime.tryParse(depAtStr)?.toLocal()
        : null;
    final depFmt = depAt != null
        ? DateFormat(
            "EEE d MMM 'à' HH:mm",
            Localizations.localeOf(context).toString(),
          ).format(depAt)
        : '—';
    final bookingId = booking['id'] as String;
    final status = booking['status'] as String? ?? 'PENDING';
    final amount = (booking['totalAmount'] as num?)?.toDouble() ?? 0;
    final isConfirmed = status == 'CONFIRMED';

    return GestureDetector(
      onTap: () => context.push('/passenger/booking/$bookingId'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isConfirmed
                ? [const Color(0xFF0C1425), const Color(0xFF1A3A5C)]
                : [const Color(0xFF78350F), const Color(0xFFCA8A04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  (isConfirmed
                          ? const Color(0xFF0C1425)
                          : const Color(0xFFCA8A04))
                      .withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.confirmation_num_outlined,
                        size: 11,
                        color: isConfirmed ? brandOrange : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConfirmed
                            ? l10n.homeNextDeparture
                            : l10n.homeAwaitingPayment,
                        style: TextStyle(
                          color: isConfirmed ? brandOrange : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$origin  →  $dest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        depFmt,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${amount.toStringAsFixed(0)} F',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.homeViewTickets,
                          style: const TextStyle(
                            color: brandOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right,
                          color: brandOrange,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
      height: 96,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
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
