import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/payment_logo.dart';
import '../../l10n/app_localizations.dart';

final _quickTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.read(authProvider).user!;
  final dio = ref.read(dioProvider);
  final res = await dio.get('/stations/${user.stationId}/trips');
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

class QuickSaleScreen extends ConsumerStatefulWidget {
  const QuickSaleScreen({super.key});
  @override
  ConsumerState<QuickSaleScreen> createState() => _State();
}

class _State extends ConsumerState<QuickSaleScreen> {
  Trip? _trip;
  int _pax = 1;
  String _method = 'CASH';
  bool _loading = false;
  bool _success = false;
  Map<String, dynamic>? _result;

  static const _methods = [
    ('CASH',         Color(0xFF16A34A)),
    ('ORANGE_MONEY', Color(0xFFEA580C)),
    ('MTN_MOMO',     Color(0xFFCA8A04)),
    ('WAVE',         Color(0xFF0284C7)),
  ];

  String _methodName(String code, AppLocalizations l10n) => switch (code) {
    'CASH'         => l10n.payMethodCash,
    'ORANGE_MONEY' => 'Orange Money',
    'MTN_MOMO'     => 'MTN MoMo',
    'WAVE'         => 'Wave',
    _              => code,
  };

  Future<void> _sell() async {
    if (_trip == null) return;
    final user = ref.read(authProvider).user!;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/bookings/guichet',
        data: {
          'tripId': _trip!.id,
          'stationId': user.stationId,
          'paymentMethod': _method,
          'passengerCount': _pax,
          'seatNumbers': <String>[],
        },
      );
      setState(() {
        _success = true;
        _result = extractData(res.data);
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      HapticFeedback.vibrate();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extractMsg(e)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractMsg(dynamic e) {
    try {
      return (e as dynamic).response?.data?['message'] ??
          AppLocalizations.of(context).error;
    } catch (_) {
      return AppLocalizations.of(context).error;
    }
  }

  void _reset() => setState(() {
    _trip = null;
    _pax = 1;
    _method = 'CASH';
    _success = false;
    _result = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    if (_success)
      return _SuccessView(
        result: _result!,
        trip: _trip!,
        pax: _pax,
        onReset: _reset,
      );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickSaleTitle)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l10n.quickSaleSelectTrip),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (_, ref, _) {
                      final async = ref.watch(_quickTripsProvider);
                      return async.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Text(
                          '${l10n.error}: $e',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                        data: (trips) {
                          if (trips.isEmpty)
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                l10n.guichetNoTripsAvailable,
                                style: TextStyle(color: context.textMuted),
                              ),
                            );
                          return Column(
                            children: trips.map((t) {
                              final sel = _trip?.id == t.id;
                              final pct = t.totalSeats > 0
                                  ? (t.totalSeats - t.availableSeats) /
                                        t.totalSeats
                                  : 0.0;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _trip = t;
                                  _pax = 1;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: sel ? brandOrange : context.cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: sel
                                          ? brandOrange
                                          : context.divider,
                                      width: sel ? 0 : 1,
                                    ),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                              color: brandOrange.withValues(
                                                alpha: 0.25,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'HH:mm',
                                            ).format(t.departureAt.toLocal()),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: sel
                                                  ? Colors.white
                                                  : brandOrange,
                                            ),
                                          ),
                                          Text(
                                            t.tripClass,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: sel
                                                  ? Colors.white70
                                                  : context.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.destinationCity,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: sel
                                                    ? Colors.white
                                                    : context.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: pct,
                                                backgroundColor: sel
                                                    ? Colors.white.withValues(
                                                        alpha: 0.3,
                                                      )
                                                    : context.divider,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      sel
                                                          ? Colors.white
                                                          : (pct > 0.8
                                                                ? Colors.red
                                                                : brandOrange),
                                                    ),
                                                minHeight: 5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.searchSeat(t.availableSeats),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: sel
                                                    ? Colors.white70
                                                    : context.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${t.price.toStringAsFixed(0)} F',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: sel
                                              ? Colors.white
                                              : brandOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),

                  if (_trip != null) ...[
                    const SizedBox(height: 20),

                    _Label(l10n.tripPassengersLabel),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BigBtn(
                          icon: Icons.remove_rounded,
                          onTap: _pax > 1 ? () => setState(() => _pax--) : null,
                        ),
                        Container(
                          width: 80,
                          alignment: Alignment.center,
                          child: Text(
                            '$_pax',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        _BigBtn(
                          icon: Icons.add_rounded,
                          onTap: _pax < (_trip!.availableSeats)
                              ? () => setState(() => _pax++)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '= ${(_trip!.price * _pax).toStringAsFixed(0)} F',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: brandOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3, 4, 5].map((n) {
                        if (n > _trip!.availableSeats)
                          return const SizedBox.shrink();
                        final sel = _pax == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _pax = n),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel ? brandOrange : context.inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: sel
                                      ? Colors.white
                                      : context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    _Label(l10n.guichetPaymentSection),
                    const SizedBox(height: 12),
                    Row(
                      children: _methods.map((m) {
                        final sel = _method == m.$1;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _method = m.$1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: sel ? m.$2.withValues(alpha: 0.10) : context.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sel ? m.$2 : context.divider,
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                                child: Column(children: [
                                  PaymentLogo(method: m.$1, size: 26),
                                  const SizedBox(height: 5),
                                  Text(
                                    _methodName(m.$1, l10n),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: sel ? m.$2 : context.textMuted,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_trip != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sell,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            l10n.quickSaleCollect(
                              NumberFormat(
                                '#,###',
                                locale,
                              ).format((_trip!.price * _pax).toInt()),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: context.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _BigBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: onTap != null ? context.tagBg : context.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onTap != null
              ? brandOrange.withValues(alpha: 0.5)
              : context.divider,
        ),
      ),
      child: Icon(
        icon,
        color: onTap != null ? brandOrange : context.textMuted,
        size: 28,
      ),
    ),
  );
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> result;
  final Trip trip;
  final int pax;
  final VoidCallback onReset;
  const _SuccessView({
    required this.result,
    required this.trip,
    required this.pax,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ref = result['reference'] as String? ?? '—';
    final total = result['totalAmount']?.toString() ?? '—';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.quickSaleSuccess,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.quickSaleTicketCount(pax)} · ${trip.originCity} → ${trip.destinationCity}',
                style: TextStyle(color: context.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.inputFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.divider),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: l10n.bookingRef, value: ref),
                    const SizedBox(height: 8),
                    _InfoRow(label: l10n.total, value: '$total F'),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: l10n.tripDeparture,
                      value: DateFormat(
                        'HH:mm',
                      ).format(trip.departureAt.toLocal()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(l10n.quickSaleNew),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.quickSaleBackToDepartures),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: TextStyle(color: context.textMuted, fontSize: 13)),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: context.textPrimary,
        ),
      ),
    ],
  );
}
