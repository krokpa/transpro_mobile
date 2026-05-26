import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class PaymentErrorScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const PaymentErrorScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentErrorScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentErrorScreen> {
  bool _loading = false;

  Future<void> _retry() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.post('/payments/bookings/${widget.bookingId}/pay');
      final checkoutUrl = res.data['checkoutUrl'] as String;
      if (mounted) {
        context.go('/passenger/payment/webview', extra: {
          'checkoutUrl': checkoutUrl,
          'bookingId': widget.bookingId,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),

            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2), shape: BoxShape.circle),
              child: const Icon(Icons.cancel_outlined,
                  color: Color(0xFFDC2626), size: 48),
            ),
            const SizedBox(height: 20),

            const Text('Paiement échoué',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: brandDark)),
            const SizedBox(height: 8),
            const Text(
              "Votre paiement n'a pas abouti.\nAucun montant n'a été débité.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF64748B), fontSize: 14, height: 1.5),
            ),

            const Spacer(),

            // Retry
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
                label: Text(_loading ? 'Chargement…' : 'Réessayer le paiement'),
                onPressed: _loading ? null : _retry,
              ),
            ),
            const SizedBox(height: 12),

            // Go to bookings
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Mes réservations'),
                onPressed: () => context.go('/passenger/bookings'),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Si le problème persiste, présentez-vous à la gare.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ]),
        ),
      ),
    );
  }
}
