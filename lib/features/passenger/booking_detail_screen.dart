import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import 'seat_picker.dart';

// ── Provider ───────────────────────────────────────────────────────────────────

final _bookingDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/bookings/my/$id');
  return res.data as Map<String, dynamic>;
});

// ── BookingDetailScreen ────────────────────────────────────────────────────────

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_bookingDetailProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la réservation')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (data) => _BookingDetail(data: data, bookingId: bookingId),
      ),
    );
  }
}

// ── _BookingDetail ─────────────────────────────────────────────────────────────

class _BookingDetail extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final String bookingId;
  const _BookingDetail({required this.data, required this.bookingId});

  @override
  ConsumerState<_BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends ConsumerState<_BookingDetail> {
  bool _payLoading = false;

  Future<void> _initiatePayment() async {
    setState(() => _payLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.post('/payments/bookings/${widget.bookingId}/pay');
      final checkoutUrl = res.data['checkoutUrl'] as String;
      if (mounted) {
        context.push('/passenger/payment/webview', extra: {
          'checkoutUrl': checkoutUrl,
          'bookingId': widget.bookingId,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _payLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = Booking.fromJson(widget.data);
    final tickets = (widget.data['tickets'] as List?) ?? [];
    final isPending = booking.status == 'PENDING';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status
        _StatusCard(booking: booking),
        const SizedBox(height: 16),

        // Pay now banner for pending bookings
        if (isPending) ...[
          _PayNowBanner(loading: _payLoading, onPay: _initiatePayment),
          const SizedBox(height: 16),
        ],

        // Trip info
        if (booking.trip != null) _TripInfoCard(trip: booking.trip!),
        const SizedBox(height: 16),

        // Track trip button when active
        if (booking.trip != null && _canTrack(booking.trip!.status)) ...[
          _TrackTripButton(trip: booking.trip!),
          const SizedBox(height: 16),
        ],

        // Tickets (QR codes)
        if (tickets.isNotEmpty) ...[
          const Text('Billets',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: brandDark)),
          const SizedBox(height: 10),
          ...tickets.map((t) => _TicketCard(ticket: t)),
        ],
      ]),
    );
  }
}

// ── Pay now banner ─────────────────────────────────────────────────────────────

class _PayNowBanner extends StatelessWidget {
  final bool loading;
  final VoidCallback onPay;
  const _PayNowBanner({required this.loading, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.access_time_outlined,
              color: Color(0xFFCA8A04), size: 18),
          SizedBox(width: 8),
          Text('Paiement en attente',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                  fontSize: 14)),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Cette réservation expire si le paiement n\'est pas effectué dans les délais.',
          style: TextStyle(color: Color(0xFF92400E), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.payment),
            label: Text(loading ? 'Chargement…' : 'Payer maintenant'),
            onPressed: loading ? null : onPay,
          ),
        ),
      ]),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

bool _canTrack(String tripStatus) =>
    tripStatus == 'BOARDING' || tripStatus == 'DEPARTED';

// ── Widgets ────────────────────────────────────────────────────────────────────

class _TrackTripButton extends StatelessWidget {
  final Trip trip;
  const _TrackTripButton({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isEnRoute = trip.status == 'DEPARTED';
    return InkWell(
      onTap: () => context.push('/track/${trip.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEnRoute
                ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                : [brandOrange, const Color(0xFFE04A10)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isEnRoute
                      ? const Color(0xFF16A34A)
                      : brandOrange)
                  .withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Icon(
            isEnRoute
                ? Icons.moving
                : Icons.directions_bus_filled,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnRoute
                        ? 'Bus en route'
                        : 'Embarquement en cours',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  Text(
                    isEnRoute
                        ? '${trip.originCity} → ${trip.destinationCity}'
                        : 'Suivre le départ en direct',
                    style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12),
                  ),
                ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ]),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Booking booking;
  const _StatusCard({required this.booking});

  static const _cfg = {
    'CONFIRMED': (Color(0xFFDCFCE7), Color(0xFF16A34A),
        Icons.check_circle_outline, 'Confirmé'),
    'PENDING': (Color(0xFFFEF9C3), Color(0xFFCA8A04),
        Icons.pending_outlined, 'En attente'),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626),
        Icons.cancel_outlined, 'Annulé'),
    'COMPLETED': (Color(0xFFF0F9FF), Color(0xFF0369A1),
        Icons.done_all, 'Terminé'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg[booking.status] ?? _cfg['PENDING']!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cfg.$1, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(cfg.$3, color: cfg.$2, size: 32),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cfg.$4,
              style: TextStyle(
                  color: cfg.$2,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          Text('Réf: ${booking.reference}',
              style:
                  TextStyle(color: cfg.$2.withValues(alpha: 0.8), fontSize: 13)),
        ]),
        const Spacer(),
        Text('${booking.totalAmount.toStringAsFixed(0)} F',
            style: TextStyle(
                color: cfg.$2,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ]),
    );
  }
}

class _TripInfoCard extends StatelessWidget {
  final Trip trip;
  const _TripInfoCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trip.routeName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: brandDark)),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                  .format(trip.departureAt.toLocal())),
          _InfoRow(
              icon: Icons.schedule,
              label: 'Heure',
              value:
                  DateFormat('HH:mm').format(trip.departureAt.toLocal())),
          _InfoRow(
              icon: Icons.event_seat_outlined,
              label: 'Classe',
              value: trip.tripClass),
          if (trip.vehiclePlate != null)
            _InfoRow(
                icon: Icons.directions_bus_outlined,
                label: 'Véhicule',
                value: trip.vehiclePlate!),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text('$label : ',
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: brandDark)),
        ]),
      );
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final qrData =
        ticket['qrCodeData'] as String? ?? ticket['qrCode'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: brandLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.confirmation_num_outlined,
                  color: brandOrange),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Siège ${ticket['seatNumber'] ?? '—'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              Text('Passager ${ticket['id']?.substring(0, 6) ?? '—'}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12)),
            ]),
          ]),
          if (qrData.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: QrImageView(data: qrData, size: 180),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── BookingCreateScreen ────────────────────────────────────────────────────────

final _tripProvider =
    FutureProvider.autoDispose.family<Trip, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/$id');
  return Trip.fromJson(res.data);
});

class BookingCreateScreen extends ConsumerStatefulWidget {
  final String tripId;
  const BookingCreateScreen({super.key, required this.tripId});

  @override
  ConsumerState<BookingCreateScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<BookingCreateScreen> {
  List<String> _selectedSeats = [];
  bool _loading = false;

  Future<void> _pickSeats(Trip trip) async {
    final seats = await showSeatPicker(
      context: context,
      tripId: widget.tripId,
      maxSeats: trip.availableSeats.clamp(1, 10),
      pricePerSeat: trip.price,
    );
    if (seats != null) setState(() => _selectedSeats = seats);
  }

  Future<void> _book() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);

      // Step 1: create the booking (→ PENDING)
      final bookingRes = await dio.post('/bookings', data: {
        'tripId': widget.tripId,
        'seatNumbers': _selectedSeats,
      });
      final bookingId = bookingRes.data['id'] as String;

      // Step 2: initiate payment → get GeniusPay checkout URL
      final payRes =
          await dio.post('/payments/bookings/$bookingId/pay');
      final checkoutUrl = payRes.data['checkoutUrl'] as String;

      if (mounted) {
        context.pushReplacement('/passenger/payment/webview', extra: {
          'checkoutUrl': checkoutUrl,
          'bookingId': bookingId,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(_tripProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver')),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (trip) {
          final fmt = NumberFormat('#,###', 'fr_FR');
          final total = _selectedSeats.length * trip.price;
          return Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip summary
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.routeName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: brandDark)),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat(
                                          'EEEE d MMMM • HH:mm',
                                          'fr_FR')
                                      .format(
                                          trip.departureAt.toLocal()),
                                  style: TextStyle(
                                      color: Colors.grey[500]),
                                ),
                                const Divider(height: 16),
                                Row(children: [
                                  Text(trip.tripClass,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(
                                    '${fmt.format(trip.price.toInt())} F / siège',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: brandOrange),
                                  ),
                                ]),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Seat selection
                      Row(children: [
                        const Expanded(
                          child: Text('Sièges',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: brandDark)),
                        ),
                        if (_selectedSeats.isNotEmpty)
                          TextButton(
                            onPressed: () => _pickSeats(trip),
                            child: const Text('Modifier'),
                          ),
                      ]),
                      const SizedBox(height: 10),

                      if (_selectedSeats.isEmpty)
                        InkWell(
                          onTap: () => _pickSeats(trip),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: brandLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: brandOrange.withAlpha(80)),
                            ),
                            child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_seat_outlined,
                                      color: brandOrange),
                                  SizedBox(width: 8),
                                  Text('Choisir vos sièges',
                                      style: TextStyle(
                                          color: brandOrange,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                ]),
                          ),
                        )
                      else
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ..._selectedSeats.map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                    color: brandOrange,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.event_seat,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(s,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                    ]),
                              )),
                          InkWell(
                            onTap: () => _pickSeats(trip),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: brandLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: brandOrange.withAlpha(80)),
                              ),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        size: 14, color: brandOrange),
                                    SizedBox(width: 4),
                                    Text('Modifier',
                                        style: TextStyle(
                                            color: brandOrange,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ]),
                            ),
                          ),
                        ]),

                      const SizedBox(height: 20),

                      // Payment note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.lock_outline,
                              color: Color(0xFF0369A1), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paiement sécurisé via GeniusPay · Orange Money, MTN MoMo, Wave et carte acceptés.',
                              style: TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ]),
                      ),
                    ]),
              ),
            ),

            // Confirm button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed:
                      (_loading || _selectedSeats.isEmpty) ? null : _book,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : _selectedSeats.isEmpty
                          ? const Text('Sélectionnez vos sièges')
                          : Text(
                              'Confirmer et payer · ${fmt.format(total.toInt())} F',
                            ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
