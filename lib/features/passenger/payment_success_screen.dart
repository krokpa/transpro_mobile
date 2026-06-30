import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const PaymentSuccessScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentSuccessScreen> {
  Map<String, dynamic>? _booking;
  bool _confirmed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/bookings/my/${widget.bookingId}');
      final data = extractData(res.data) as Map<String, dynamic>;
      if (!mounted) return;
      final wasConfirmed = _confirmed;
      setState(() {
        _booking   = data;
        _confirmed = data['status'] == 'CONFIRMED';
      });
      if (_confirmed) {
        _timer?.cancel();
        if (!wasConfirmed) _scheduleReminder(data);
      }
    } catch (_) {}
  }

  void _scheduleReminder(Map<String, dynamic> booking) {
    try {
      final trip      = booking['trip'] as Map<String, dynamic>?;
      final route     = trip?['route'] as Map<String, dynamic>?;
      final depStr    = trip?['departureAt'] as String?;
      final origin    = route?['originCity']?['name'] as String? ?? '';
      final dest      = route?['destinationCity']?['name'] as String? ?? '';
      final departure = depStr != null ? DateTime.tryParse(depStr) : null;
      final id        = booking['id'] as String?;

      if (id != null && departure != null && origin.isNotEmpty) {
        LocalNotificationService.scheduleBookingReminder(
          bookingId: id,
          origin: origin,
          destination: dest,
          departureAt: departure,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _confirmed && _booking != null
              ? _SuccessBody(booking: _booking!, bookingId: widget.bookingId)
              : const _LoadingBody(),
        ),
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: brandOrange),
        const SizedBox(height: 20),
        Text(l10n.paymentConfirming,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary)),
        const SizedBox(height: 8),
        Text(l10n.paymentPleaseWait,
            style: TextStyle(color: context.textMuted, fontSize: 13)),
      ]),
    );
  }
}

// ── Success ────────────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String bookingId;
  const _SuccessBody({required this.booking, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final fmt    = NumberFormat('#,###', 'fr_FR');
    final trip   = booking['trip'] as Map<String, dynamic>?;
    final route  = trip?['route'] as Map<String, dynamic>?;
    final origin = route?['originCity']?['name'] ?? '';
    final dest   = route?['destinationCity']?['name'] ?? '';
    final dep    = trip != null ? DateTime.tryParse(trip['departureAt'] ?? '') : null;
    final seats  = List<String>.from(booking['seatNumbers'] ?? []);
    final amount = (booking['totalAmount'] as num?)?.toInt() ?? 0;

    return Column(children: [
      const Spacer(),

      Container(
        width: 88, height: 88,
        decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 48),
      ),
      const SizedBox(height: 20),

      Text(l10n.paymentSuccess,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 8),
      Text(l10n.paymentTicketReady,
          style: TextStyle(color: context.textSecondary, fontSize: 14)),

      const Spacer(),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider),
        ),
        child: Column(children: [
          if (origin.isNotEmpty)
            _Row(l10n.paymentTripLabel, '$origin → $dest'),
          if (dep != null)
            _Row(l10n.date, DateFormat('EEE d MMM · HH:mm', locale).format(dep.toLocal())),
          if (seats.isNotEmpty)
            _Row(l10n.paymentSeatsLabel, seats.join(', ')),
          const Divider(height: 20),
          Row(children: [
            Text(l10n.paymentTotalPaidLabel,
                style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const Spacer(),
            Text('${fmt.format(amount)} FCFA',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF16A34A), fontSize: 16)),
          ]),
        ]),
      ),

      const Spacer(),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.confirmation_num_outlined),
          label: Text(l10n.paymentGoToTicket),
          onPressed: () => context.go('/passenger/booking/$bookingId'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.go('/passenger'),
        child: Text(l10n.paymentGoHome, style: TextStyle(color: context.textMuted)),
      ),
    ]);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimary)),
        ]),
      );
}
