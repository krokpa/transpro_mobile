import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

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
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _booking = data;
        _confirmed = data['status'] == 'CONFIRMED';
      });
      if (_confirmed) _timer?.cancel();
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
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: brandOrange),
        SizedBox(height: 20),
        Text('Confirmation du paiement…',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: brandDark)),
        SizedBox(height: 8),
        Text('Merci de patienter quelques instants.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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
    final fmt = NumberFormat('#,###', 'fr_FR');
    final trip = booking['trip'] as Map<String, dynamic>?;
    final route = trip?['route'] as Map<String, dynamic>?;
    final origin = route?['originCity']?['name'] ?? '';
    final dest = route?['destinationCity']?['name'] ?? '';
    final dep = trip != null
        ? DateTime.tryParse(trip['departureAt'] ?? '')
        : null;
    final seats = List<String>.from(booking['seatNumbers'] ?? []);
    final amount = (booking['totalAmount'] as num?)?.toInt() ?? 0;

    return Column(children: [
      const Spacer(),

      // Icon
      Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_outline,
            color: Color(0xFF16A34A), size: 48),
      ),
      const SizedBox(height: 20),

      const Text('Paiement réussi !',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: brandDark)),
      const SizedBox(height: 8),
      const Text('Votre billet est confirmé et prêt.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),

      const Spacer(),

      // Summary card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(children: [
          if (origin.isNotEmpty)
            _Row('Trajet', '$origin → $dest'),
          if (dep != null)
            _Row('Date',
                DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(dep.toLocal())),
          if (seats.isNotEmpty) _Row('Sièges', seats.join(', ')),
          const Divider(height: 20),
          Row(children: [
            const Text('Total payé',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const Spacer(),
            Text('${fmt.format(amount)} FCFA',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                    fontSize: 16)),
          ]),
        ]),
      ),

      const Spacer(),

      // CTA
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.confirmation_num_outlined),
          label: const Text('Voir mon billet'),
          onPressed: () => context.go('/passenger/booking/$bookingId'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.go('/passenger'),
        child: const Text("Retour à l'accueil",
            style: TextStyle(color: Color(0xFF94A3B8))),
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
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: brandDark)),
        ]),
      );
}
