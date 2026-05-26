import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

final _myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/bookings/my');
  final items = extractData(res.data);
  return (items as List).map((e) => Booking.fromJson(e)).toList();
});

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes billets')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (bookings) => bookings.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.confirmation_num_outlined, size: 36, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucun billet',
                    style: TextStyle(fontWeight: FontWeight.w700, color: brandDark, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Réservez votre premier voyage dès maintenant.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/passenger/search'),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Rechercher un voyage'),
                    style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  ),
                ]),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(_myBookingsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
                ),
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  static const _statusConfig = {
    'CONFIRMED': (Color(0xFFDCFCE7), Color(0xFF16A34A), 'Confirmé',    Icons.check_circle_outline),
    'PENDING':   (Color(0xFFFEF9C3), Color(0xFFCA8A04), 'En attente',  Icons.schedule_outlined),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), 'Annulé',      Icons.cancel_outlined),
    'COMPLETED': (Color(0xFFF0F9FF), Color(0xFF0369A1), 'Terminé',     Icons.done_all_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[booking.status] ?? _statusConfig['PENDING']!;
    final trip = booking.trip;
    final isPending = booking.status == 'PENDING';
    final isActive = trip != null && (trip.status == 'BOARDING' || trip.status == 'DEPARTED');

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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.$4, size: 12, color: cfg.$2),
                    const SizedBox(width: 4),
                    Text(cfg.$3, style: TextStyle(color: cfg.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (trip != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE d MMM yyyy • HH:mm', 'fr_FR').format(trip.departureAt.toLocal()),
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ]),
              ],
              const Divider(height: 18),
              Row(children: [
                const Icon(Icons.confirmation_num_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  booking.reference,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'monospace'),
                ),
                const Spacer(),
                Text(
                  '${booking.totalAmount.toStringAsFixed(0)} F',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: brandOrange, fontSize: 15),
                ),
              ]),
            ]),
          ),

          // Pending payment banner
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
                const Expanded(
                  child: Text(
                    'Paiement en attente — appuyez pour payer',
                    style: TextStyle(color: Color(0xFFCA8A04), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCA8A04)),
              ]),
            ),
          ],

          // Live tracking button for active trips
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
                    trip.status == 'DEPARTED' ? 'Suivre en direct' : 'Embarquement — Suivre',
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
