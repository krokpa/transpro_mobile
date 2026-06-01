import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geniuspay_flutter/geniuspay_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

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
      final dio      = ref.read(dioProvider);
      final authUser = ref.read(authProvider);

      // Charger le montant de la réservation
      final res      = await dio.get('/bookings/my/${widget.bookingId}');
      final data     = extractData(res.data) as Map<String, dynamic>;
      final amount   = (data['totalAmount'] as num).toDouble();

      if (!mounted) return;

      final result = await GeniusPaySheet.show(
        context,
        amount:      amount,
        currency:    'XOF',
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

      if (result == null || result.status != PaymentStatus.completed) return;

      await dio.post(
        '/payments/bookings/${widget.bookingId}/confirm-native',
        data: {'geniusPayReference': result.reference},
      );

      if (mounted) {
        context.go('/passenger/payment/success/${widget.bookingId}');
      }
    } catch (e) {
      if (mounted) {
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFDC2626),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                l10n.paymentFailed,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.paymentErrorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_loading ? l10n.loading : l10n.paymentRetry),
                  onPressed: _loading ? null : _retry,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt_outlined),
                  label: Text(l10n.bookingsTitle),
                  onPressed: () => context.go('/passenger/bookings'),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                l10n.paymentGotoStationHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
