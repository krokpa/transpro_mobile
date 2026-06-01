import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/offline/ticket_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fade_slide.dart';
import '../../l10n/app_localizations.dart';

final _myBookingsProvider = FutureProvider.autoDispose<({List<Booking> bookings, bool isOffline})>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/bookings/my');
    final items = extractData(res.data) as List;
    await TicketCache.saveBookingList(items);
    final bookings = items.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    return (bookings: bookings, isOffline: false);
  } catch (_) {
    final cached = TicketCache.getBookings();
    if (cached.isNotEmpty) {
      return (bookings: cached.map((e) => Booking.fromJson(e)).toList(), isOffline: true);
    }
    rethrow;
  }
});

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n  = AppLocalizations.of(context);
    final async = ref.watch(_myBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (result) {
          final bookings  = result.bookings;
          final isOffline = result.isOffline;

          if (bookings.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: context.inputFill, shape: BoxShape.circle),
                  child: Icon(Icons.confirmation_num_outlined, size: 36, color: context.textMuted),
                ),
                const SizedBox(height: 16),
                Text(l10n.bookingsNoBookings,
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary, fontSize: 16)),
                const SizedBox(height: 6),
                Text(l10n.bookingsNoBookingsSub,
                  style: TextStyle(color: context.textMuted, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/passenger/search'),
                  icon: const Icon(Icons.search_rounded),
                  label: Text(l10n.bookingsSearchTrips),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ]),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_myBookingsProvider.future),
            child: Column(children: [
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFFEF9C3),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFCA8A04)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      l10n.bookingsOfflineMode,
                      style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (_, i) => FadeSlideIn(
                    delay: Duration(milliseconds: (i * 60).clamp(0, 240)),
                    child: _BookingCard(booking: bookings[i]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  static const _statusColors = <String, (Color, Color, IconData)>{
    'CONFIRMED': (Color(0xFFDCFCE7), Color(0xFF16A34A), Icons.check_circle_outline),
    'PENDING':   (Color(0xFFFEF9C3), Color(0xFFCA8A04), Icons.schedule_outlined),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), Icons.cancel_outlined),
    'COMPLETED': (Color(0xFFF0F9FF), Color(0xFF0369A1), Icons.done_all_rounded),
  };

  String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
    'CONFIRMED' => l10n.bookingStatusConfirmed,
    'PENDING'   => l10n.bookingStatusPending,
    'CANCELLED' => l10n.bookingStatusCancelled,
    'COMPLETED' => l10n.bookingStatusCompleted,
    _           => status,
  };

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context);
    final cfg       = _statusColors[booking.status] ?? _statusColors['PENDING']!;
    final trip      = booking.trip;
    final isPending = booking.status == 'PENDING';
    final isActive  = trip != null && (trip.status == 'BOARDING' || trip.status == 'DEPARTED');
    final locale    = Localizations.localeOf(context).toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/passenger/booking/${booking.id}'),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  trip?.routeName ?? '—',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.$3, size: 12, color: cfg.$2),
                    const SizedBox(width: 4),
                    Text(_statusLabel(booking.status, l10n),
                      style: TextStyle(color: cfg.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (trip != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE d MMM yyyy • HH:mm', locale).format(trip.departureAt.toLocal()),
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
                ]),
              ],
              const Divider(height: 18),
              Row(children: [
                Icon(Icons.confirmation_num_outlined, size: 14, color: context.textMuted),
                const SizedBox(width: 6),
                Text(
                  booking.reference,
                  style: TextStyle(color: context.textSecondary, fontSize: 12, fontFamily: 'monospace'),
                ),
                const Spacer(),
                Text(
                  '${booking.totalAmount.toStringAsFixed(0)} F',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: brandOrange, fontSize: 15),
                ),
              ]),
            ]),
          ),

          if (isPending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF9C3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.payments_outlined, size: 14, color: Color(0xFFCA8A04)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.bookingsPendingPay,
                    style: const TextStyle(color: Color(0xFFCA8A04), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCA8A04)),
              ]),
            ),
          ],

          // Luggage status shortcut
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/passenger/booking/${booking.id}/luggage?ref=${booking.reference}',
                ),
                icon: const Icon(Icons.luggage_outlined, size: 15),
                label: const Text('Mes bagages'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          if (isActive && !isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/track/${trip.id}'),
                  icon: Icon(
                    trip.status == 'DEPARTED' ? Icons.moving_rounded : Icons.directions_bus_filled_rounded,
                    size: 16,
                  ),
                  label: Text(
                    trip.status == 'DEPARTED' ? l10n.bookingsTrackLive : l10n.bookingsTrackBoarding,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: trip.status == 'DEPARTED' ? const Color(0xFF16A34A) : brandOrange,
                    side: BorderSide(
                      color: trip.status == 'DEPARTED' ? const Color(0xFF16A34A) : brandOrange,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
