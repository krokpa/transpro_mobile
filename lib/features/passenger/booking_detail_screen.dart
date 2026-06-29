import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geniuspay_flutter/geniuspay_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/connectivity/require_online.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/models/models.dart';
import '../../core/offline/ticket_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';
import 'seat_picker.dart';

// ── Provider ───────────────────────────────────────────────────────────────────

final _bookingDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/bookings/my/$id');
        final data = extractData(res.data) as Map<String, dynamic>;
        await TicketCache.saveBooking(data);
        return data;
      } catch (_) {
        final cached = TicketCache.getBooking(id);
        if (cached != null) return cached;
        rethrow;
      }
    });

// ── BookingDetailScreen ────────────────────────────────────────────────────────

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_bookingDetailProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookingDetailTitle)),
      body: async.when(
        loading: () => AppShimmer.listTiles(count: 6),
        error: (e, _) => AppErrorView(error: e),
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
  int _selectedRating = 0;
  bool _ratingLoading = false;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _ratingLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/bookings/my/${widget.bookingId}/rate',
        data: {
          'rating': _selectedRating,
          if (_commentCtrl.text.trim().isNotEmpty)
            'comment': _commentCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bookingRateThankYou),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        ref.invalidate(_bookingDetailProvider(widget.bookingId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
  }

  void _shareTrip(Booking booking) {
    final locale = Localizations.localeOf(context).toString();
    final origin = booking.trip?.originCity ?? '';
    final dest = booking.trip?.destinationCity ?? '';
    final depAt = booking.trip != null
        ? DateFormat(
            "EEEE d MMM 'à' HH:mm",
            locale,
          ).format(booking.trip!.departureAt.toLocal())
        : '';
    Share.share(
      'TransPro CI — $origin → $dest, $depAt',
      subject: 'Mon voyage TransPro',
    );
  }

  Future<void> _initiatePayment() async {
    if (!requireOnline(context, ref)) return;
    final booking  = Booking.fromJson(widget.data);
    final authUser = ref.read(authProvider);
    setState(() => _payLoading = true);
    try {
      final result = await GeniusPaySheet.show(
        context,
        amount:   booking.totalAmount.toDouble(),
        currency: 'XOF',
        description: 'Réservation TransPro — ${widget.bookingId}',
        defaultCustomer: Customer(
          name:  '${authUser.user?.firstName ?? ''} ${authUser.user?.lastName ?? ''}'.trim(),
          email: authUser.user?.email ?? '',
          phone: authUser.user?.phone ?? '',
        ),
        allowedMethods: [
          PaymentMethod.wave,
          PaymentMethod.orangeMoney,
          PaymentMethod.mtnMoney,
        ],
        metadata: {'bookingId': widget.bookingId},
      );

      if (result == null || result.status != PaymentStatus.completed) {
        if (mounted && result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).paymentFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Confirmer côté backend (crée le Payment en DB + confirme la réservation)
      final dio = ref.read(dioProvider);
      await dio.post(
        '/payments/bookings/${widget.bookingId}/confirm-native',
        data: {'geniusPayReference': result.reference},
      );

      if (mounted) {
        context.pushReplacement('/passenger/payment/success/${widget.bookingId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _payLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booking = Booking.fromJson(widget.data);
    final tickets = (widget.data['tickets'] as List?) ?? [];
    final isPending = booking.status == 'PENDING';
    final isCompleted = booking.status == 'COMPLETED';
    final existingRating = widget.data['rating'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(booking: booking),
          const SizedBox(height: 16),

          if (isPending) ...[
            _PayNowBanner(loading: _payLoading, onPay: _initiatePayment),
            const SizedBox(height: 16),
          ],

          if (booking.trip != null) _TripInfoCard(trip: booking.trip!),
          const SizedBox(height: 16),

          if (booking.trip != null && _canTrack(booking.trip!.status)) ...[
            _TrackTripButton(trip: booking.trip!),
            const SizedBox(height: 16),
          ],

          OutlinedButton.icon(
            onPressed: () => _shareTrip(booking),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(l10n.bookingShareTrip),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: context.divider),
              foregroundColor: context.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (isCompleted) ...[
            _RatingSection(
              existingRating: existingRating,
              selectedRating: _selectedRating,
              loading: _ratingLoading,
              commentCtrl: _commentCtrl,
              onStarTap: (s) => setState(() => _selectedRating = s),
              onSubmit: _submitRating,
            ),
            const SizedBox(height: 16),
          ],

          _LuggageSection(bookingId: widget.bookingId),
          const SizedBox(height: 16),

          if (tickets.isNotEmpty) ...[
            Text(
              l10n.bookingTicketsSection,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...tickets.map((t) => _TicketCard(ticket: t, trip: booking.trip)),
          ],
        ],
      ),
    );
  }
}

// ── Luggage section ───────────────────────────────────────────────────────────

const _statusColors = {
  'DECLARED': Color(0xFF94A3B8),
  'LOADED':   Color(0xFF3B82F6),
  'ARRIVED':  Color(0xFFF59E0B),
  'CLAIMED':  Color(0xFF16A34A),
  'MISSING':  Color(0xFFEF4444),
};

const _statusLabels = {
  'DECLARED': 'Déclaré',
  'LOADED':   'Chargé',
  'ARRIVED':  'Arrivé',
  'CLAIMED':  'Réclamé',
  'MISSING':  'Manquant',
};

const _progressSteps = ['DECLARED', 'LOADED', 'ARRIVED', 'CLAIMED'];

class _LuggageSection extends ConsumerWidget {
  final String bookingId;
  const _LuggageSection({required this.bookingId});

  Future<Map<String, dynamic>?> _fetch(WidgetRef ref) async {
    try {
      final res  = await ref.read(dioProvider).get('/luggage/my/$bookingId');
      final data = extractData(res.data);
      if (data == null) return null;
      return data as Map<String, dynamic>;
    } catch (_) {
      return null; // plan BASIC, not declared, or error — hide silently
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetch(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();

        final bags = (snap.data!['bags'] as List?) ?? [];
        if (bags.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.luggage_outlined, size: 18, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text('Bagages',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${bags.length} sac${bags.length > 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
            ),
          ]),
          const SizedBox(height: 12),
          ...bags.map((b) => _BagProgressTile(bag: b as Map<String, dynamic>)),
        ]);
      },
    );
  }
}

class _BagProgressTile extends StatelessWidget {
  final Map<String, dynamic> bag;
  const _BagProgressTile({required this.bag});

  @override
  Widget build(BuildContext context) {
    final status  = bag['status'] as String? ?? 'DECLARED';
    final label   = bag['label']  as String?;
    final weight  = bag['weightKg'];
    final color   = _statusColors[status] ?? const Color(0xFF94A3B8);
    final isMissing = status == 'MISSING';
    final stepIdx = _progressSteps.indexOf(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.luggage_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              label ?? 'Sac',
              style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary, fontSize: 14),
            )),
            if (weight != null)
              Text('${weight}kg', style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabels[status] ?? status,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),

          if (!isMissing) ...[
            const SizedBox(height: 12),
            Row(children: List.generate(_progressSteps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final lineIdx = i ~/ 2;
                final filled  = stepIdx > lineIdx;
                return Expanded(child: Container(height: 2,
                  color: filled ? brandOrange : context.divider));
              }
              final sIdx   = i ~/ 2;
              final filled = stepIdx >= sIdx;
              final active = stepIdx == sIdx;
              return Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape:       BoxShape.circle,
                  color:       filled ? brandOrange : Colors.transparent,
                  border:      active
                      ? Border.all(color: brandOrange, width: 2.5)
                      : filled
                          ? null
                          : Border.all(color: context.divider, width: 1.5),
                ),
                child: filled
                    ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                    : null,
              );
            })),
          ] else ...[
            const SizedBox(height: 8),
            if (bag['missingNote'] != null)
              Text('Note : ${bag['missingNote']}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
          ],
        ],
      ),
    );
  }
}

// ── Rating section ────────────────────────────────────────────────────────────

class _RatingSection extends StatelessWidget {
  final Map<String, dynamic>? existingRating;
  final int selectedRating;
  final bool loading;
  final TextEditingController commentCtrl;
  final ValueChanged<int> onStarTap;
  final VoidCallback onSubmit;

  const _RatingSection({
    required this.existingRating,
    required this.selectedRating,
    required this.loading,
    required this.commentCtrl,
    required this.onStarTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existingRating != null
                ? l10n.bookingRateYourReview
                : l10n.bookingRateTrip,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (existingRating != null) ...[
            Row(
              children: List.generate(5, (i) {
                final filled = i < (existingRating!['rating'] as int? ?? 0);
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 28,
                  color: filled ? const Color(0xFFFBBF24) : context.divider,
                );
              }),
            ),
            if ((existingRating!['comment'] as String?)?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 8),
              Text(
                '"${existingRating!['comment']}"',
                style: TextStyle(
                  color: context.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ] else ...[
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                final active = star <= selectedRating;
                return GestureDetector(
                  onTap: () => onStarTap(star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: active ? const Color(0xFFFBBF24) : context.divider,
                    ),
                  ),
                );
              }),
            ),

            if (selectedRating > 0) ...[
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n.bookingRateComment,
                  hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.bookingRateSubmit,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ],
        ],
      ),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                color: Color(0xFFCA8A04),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.bookingPayPendingTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.bookingPayPendingBody,
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payment),
              label: Text(loading ? l10n.loading : l10n.bookingPayNow),
              onPressed: loading ? null : onPay,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

bool _canTrack(String tripStatus) =>
    tripStatus == 'BOARDING' || tripStatus == 'DEPARTED';

// ── Track trip button ──────────────────────────────────────────────────────────

class _TrackTripButton extends StatelessWidget {
  final Trip trip;
  const _TrackTripButton({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEnRoute = trip.status == 'DEPARTED';
    return InkWell(
      onTap: () => context.push('/track/${trip.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isEnRoute
                ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                : [brandOrange, const Color(0xFFE04A10)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isEnRoute ? const Color(0xFF16A34A) : brandOrange)
                  .withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isEnRoute ? Icons.moving : Icons.directions_bus_filled,
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
                        ? l10n.bookingBusEnRoute
                        : l10n.tripStatusBoarding,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isEnRoute
                        ? '${trip.originCity} → ${trip.destinationCity}'
                        : l10n.bookingTrackBoardingSub,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final Booking booking;
  const _StatusCard({required this.booking});

  static const _cfg = <String, (Color, Color, IconData)>{
    'CONFIRMED': (
      Color(0xFFDCFCE7),
      Color(0xFF16A34A),
      Icons.check_circle_outline,
    ),
    'PENDING': (Color(0xFFFEF9C3), Color(0xFFCA8A04), Icons.pending_outlined),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), Icons.cancel_outlined),
    'COMPLETED': (Color(0xFFF0F9FF), Color(0xFF0369A1), Icons.done_all),
  };

  String _label(String status, AppLocalizations l10n) => switch (status) {
    'CONFIRMED' => l10n.bookingStatusConfirmed,
    'PENDING' => l10n.bookingStatusPending,
    'CANCELLED' => l10n.bookingStatusCancelled,
    'COMPLETED' => l10n.bookingStatusCompleted,
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cfg = _cfg[booking.status] ?? _cfg['PENDING']!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.$1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(cfg.$3, color: cfg.$2, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(booking.status, l10n),
                style: TextStyle(
                  color: cfg.$2,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '${l10n.bookingRefPrefix}: ${booking.reference}',
                style: TextStyle(
                  color: cfg.$2.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${booking.totalAmount.toStringAsFixed(0)} F',
            style: TextStyle(
              color: cfg.$2,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tenant logo ────────────────────────────────────────────────────────────────

// ── Trip info card ─────────────────────────────────────────────────────────────

class _TripInfoCard extends StatelessWidget {
  final Trip trip;
  const _TripInfoCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trip.tenantName != null) ...[
              GestureDetector(
                onTap: trip.tenantSlug != null
                    ? () =>
                          context.push('/passenger/company/${trip.tenantSlug}')
                    : null,
                child: Row(
                  children: [
                    CompanyLogo(logo: trip.tenantLogo, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.tenantName!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            trip.routeName,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trip.tenantSlug != null)
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.textMuted,
                      ),
                  ],
                ),
              ),
              const Divider(height: 20),
            ] else ...[
              Text(
                trip.routeName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: l10n.date,
              value: DateFormat(
                'EEEE d MMMM yyyy',
                locale,
              ).format(trip.departureAt.toLocal()),
            ),
            _InfoRow(
              icon: Icons.schedule,
              label: l10n.time,
              value: DateFormat('HH:mm').format(trip.departureAt.toLocal()),
            ),
            _InfoRow(
              icon: Icons.event_seat_outlined,
              label: l10n.tripClass,
              value: trip.tripClass,
            ),
            if (trip.vehiclePlate != null)
              _InfoRow(
                icon: Icons.directions_bus_outlined,
                label: l10n.tripInfoVehicle,
                value: trip.vehiclePlate!,
              ),
            if (trip.departureStationId != null)
              _TappableInfoRow(
                icon: Icons.location_on_outlined,
                label: l10n.tripInfoDepartureStation,
                value: trip.departureStationAddress != null
                    ? '${trip.departureStationName!} · ${trip.departureStationAddress}'
                    : trip.departureStationName!,
                onTap: () => context.push(
                  '/passenger/station/${trip.departureStationId}',
                ),
              ),
            if (trip.arrivalStationId != null)
              _TappableInfoRow(
                icon: Icons.location_on,
                label: l10n.tripInfoArrivalStation,
                value: trip.arrivalStationAddress != null
                    ? '${trip.arrivalStationName!} · ${trip.arrivalStationAddress}'
                    : trip.arrivalStationName!,
                onTap: () =>
                    context.push('/passenger/station/${trip.arrivalStationId}'),
              ),

            // Route timeline (only when there are intermediate stops)
            if (trip.stops.isNotEmpty) ...[
              const Divider(height: 20),
              _RouteTimeline(trip: trip),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _RouteTimeline ────────────────────────────────────────────────────────────

class _RouteTimeline extends StatelessWidget {
  final Trip trip;
  const _RouteTimeline({required this.trip});

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h h $m';
  }

  @override
  Widget build(BuildContext context) {
    final dep = trip.departureAt.toLocal();
    final stops = trip.stops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Itinéraire',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Departure
        _TimelinePoint(
          time: _fmt(dep),
          label: trip.originCity,
          isFirst: true,
          isLast: false,
        ),
        // Intermediate stops
        for (final stop in stops)
          _TimelinePoint(
            time: _fmt(dep.add(Duration(minutes: stop.durationFromOriginMinutes))),
            label: stop.cityName ?? '—',
            price: stop.priceFromOrigin > 0 ? '${stop.priceFromOrigin} F' : null,
            isFirst: false,
            isLast: false,
          ),
        // Arrival
        _TimelinePoint(
          time: trip.estimatedArrivalAt != null
              ? _fmt(trip.estimatedArrivalAt!.toLocal())
              : '—',
          label: trip.destinationCity,
          isFirst: false,
          isLast: true,
        ),
      ],
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  final String time;
  final String label;
  final String? price;
  final bool isFirst;
  final bool isLast;

  const _TimelinePoint({
    required this.time,
    required this.label,
    this.price,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    const dotSize = 10.0;
    const lineW = 2.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column
          SizedBox(
            width: 50,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 2),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          // Dot + line column
          Column(
            children: [
              // Top line
              if (!isFirst)
                Expanded(
                  child: Center(
                    child: Container(width: lineW, color: const Color(0xFFE5E7EB)),
                  ),
                )
              else
                const SizedBox(height: 6),
              // Dot
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst || isLast ? brandOrange : const Color(0xFF3B82F6),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isFirst || isLast ? brandOrange : const Color(0xFF3B82F6))
                          .withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              // Bottom line
              if (!isLast)
                Expanded(
                  child: Center(
                    child: Container(width: lineW, color: const Color(0xFFE5E7EB)),
                  ),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
          // Label + price column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 16, top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 0),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFirst || isLast ? FontWeight.w700 : FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  if (price != null)
                    Text(
                      price!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TappableInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TappableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: brandOrange),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: brandOrange,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: brandOrange),
        ],
      ),
    ),
  );
}

// ── Ticket card ────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Trip? trip;
  const _TicketCard({required this.ticket, this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final qrData =
        ticket['qrCodeData'] as String? ?? ticket['qrCode'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brandOrange, Color(0xFFE04A10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                if (trip?.tenantLogo != null)
                  CompanyLogo.onDark(logo: trip!.tenantLogo, size: 40)
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.confirmation_num_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip?.tenantName ?? 'TransPro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (trip != null)
                        Text(
                          '${trip!.originCity} → ${trip!.destinationCity}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.bookingSeatNumber('${ticket['seatNumber'] ?? '—'}'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // QR section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (trip != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat(
                          'EEE d MMM · HH:mm',
                          locale,
                        ).format(trip!.departureAt.toLocal()),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (qrData.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.divider),
                    ),
                    child: QrImageView(data: qrData, size: 180),
                  )
                else
                  Text(
                    l10n.bookingQrUnavailable,
                    style: TextStyle(color: context.textMuted),
                  ),
                const SizedBox(height: 8),
                Text(
                  l10n.bookingQrInstruction,
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── BookingCreateScreen ────────────────────────────────────────────────────────

final _tripProvider = FutureProvider.autoDispose.family<Trip, String>((
  ref,
  id,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/$id');
  return Trip.fromJson(extractData(res.data));
});

class BookingCreateScreen extends ConsumerStatefulWidget {
  final String tripId;
  const BookingCreateScreen({super.key, required this.tripId});

  @override
  ConsumerState<BookingCreateScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<BookingCreateScreen> {
  List<String> _selectedSeats = [];
  int _passengerCount = 1;
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

  Future<void> _book(Trip trip) async {
    if (!requireOnline(context, ref)) return;
    setState(() => _loading = true);
    String? bookingId;
    try {
      final dio      = ref.read(dioProvider);
      final authUser = ref.read(authProvider);

      // 1. Créer la réservation
      final Map<String, dynamic> payload = {'tripId': widget.tripId};
      if (trip.advancedSeatManagement) {
        payload['seatNumbers'] = _selectedSeats;
      } else {
        payload['passengerCount'] = _passengerCount;
        payload['seatNumbers'] = <String>[];
      }
      final bookingRes = await dio.post('/bookings', data: payload);
      final bookingData = extractData(bookingRes.data) as Map<String, dynamic>;
      bookingId = bookingData['id'] as String;
      final amount = (bookingData['totalAmount'] as num).toDouble();

      // 2. Paiement natif GeniusPay
      if (!mounted) return;
      final result = await GeniusPaySheet.show(
        context,
        amount:      amount,
        currency:    'XOF',
        description: 'Réservation TransPro — $bookingId',
        defaultCustomer: Customer(
          name:  '${authUser.user?.firstName ?? ''} ${authUser.user?.lastName ?? ''}'.trim(),
          email: authUser.user?.email ?? '',
          phone: authUser.user?.phone ?? '',
        ),
        allowedMethods: [
          PaymentMethod.wave,
          PaymentMethod.orangeMoney,
          PaymentMethod.mtnMoney,
        ],
        metadata: {'bookingId': bookingId},
      );

      if (result == null || result.status != PaymentStatus.completed) {
        // Paiement annulé — aller au détail de la réservation (en attente)
        if (mounted) context.pushReplacement('/passenger/booking/$bookingId');
        return;
      }

      // 3. Confirmer côté backend
      await dio.post(
        '/payments/bookings/$bookingId/confirm-native',
        data: {'geniusPayReference': result.reference},
      );

      if (mounted) {
        context.pushReplacement('/passenger/payment/success/$bookingId');
      }
    } catch (e) {
      if (mounted) {
        if (bookingId != null) {
          context.pushReplacement('/passenger/booking/$bookingId');
        } else {
          setState(() => _selectedSeats = []);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tripAsync = ref.watch(_tripProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripBook)),
      body: tripAsync.when(
        loading: () => AppShimmer.tripCards(count: 2),
        error: (e, _) => AppErrorView(error: e),
        data: (trip) {
          final locale = Localizations.localeOf(context).toString();
          final fmt = NumberFormat('#,###', 'fr_FR');
          final useASM = trip.advancedSeatManagement;
          final total = useASM
              ? _selectedSeats.length * trip.price
              : _passengerCount * trip.price;
          final canBook = useASM ? _selectedSeats.isNotEmpty : true;

          return Column(
            children: [
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
                              Text(
                                trip.routeName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat(
                                  'EEEE d MMMM • HH:mm',
                                  locale,
                                ).format(trip.departureAt.toLocal()),
                                style: TextStyle(color: context.textMuted),
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Text(
                                    trip.tripClass,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    l10n.bookingPricePerSeat(
                                      fmt.format(trip.price.toInt()),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: brandOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (useASM) ...[
                        // Seat picker (ASM ON)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.bookingSeats,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            if (_selectedSeats.isNotEmpty)
                              TextButton(
                                onPressed: () => _pickSeats(trip),
                                child: Text(l10n.bookingModifySeats),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_selectedSeats.isEmpty)
                          InkWell(
                            onTap: () => _pickSeats(trip),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.tagBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: brandOrange.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.event_seat_outlined,
                                    color: brandOrange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.bookingChooseSeats,
                                    style: const TextStyle(
                                      color: brandOrange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._selectedSeats.map(
                                (s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brandOrange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_seat,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        s,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _pickSeats(trip),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.tagBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: brandOrange.withAlpha(80),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add,
                                        size: 14,
                                        color: brandOrange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.bookingModifySeats,
                                        style: const TextStyle(
                                          color: brandOrange,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ] else ...[
                        // Quantity selector (ASM OFF)
                        Text(
                          l10n.tripPassengersLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _CountBtn(
                              icon: Icons.remove,
                              onTap: _passengerCount > 1
                                  ? () => setState(() => _passengerCount--)
                                  : null,
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '$_passengerCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 20),
                            _CountBtn(
                              icon: Icons.add,
                              onTap: _passengerCount < trip.availableSeats
                                  ? () => setState(() => _passengerCount++)
                                  : null,
                            ),
                            const Spacer(),
                            Text(
                              '= ${fmt.format((_passengerCount * trip.price).toInt())} F',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: brandOrange,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Payment note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF0369A1),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.bookingPaymentNote,
                                style: const TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Confirm button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ElevatedButton(
                    onPressed: (_loading || !canBook)
                        ? null
                        : () => _book(trip),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : (!canBook)
                        ? Text(l10n.bookingSelectSeatsPrompt)
                        : Text(
                            l10n.bookingConfirmAndPay(
                              fmt.format(total.toInt()),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onTap != null
            ? brandOrange.withValues(alpha: 0.1)
            : context.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap != null ? brandOrange : context.textMuted,
      ),
    ),
  );
}
