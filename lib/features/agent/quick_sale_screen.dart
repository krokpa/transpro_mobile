import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/phone_input_field.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _quickTripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final user = ref.read(authProvider).user!;
  final dio  = ref.read(dioProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final res = await dio.get(
    '/stations/${user.stationId}/trips',
    queryParameters: {
      'date':   today,
      'status': 'SCHEDULED,BOARDING',
    },
  );
  final items = extractData(res.data);
  return (items as List).map((e) => Trip.fromJson(e)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class QuickSaleScreen extends ConsumerStatefulWidget {
  const QuickSaleScreen({super.key});
  @override
  ConsumerState<QuickSaleScreen> createState() => _State();
}

class _State extends ConsumerState<QuickSaleScreen> {
  Trip?   _trip;
  int     _pax    = 1;
  bool    _loading = false;
  bool    _success = false;
  Map<String, dynamic>? _result;

  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sell() async {
    if (_trip == null) return;
    final user = ref.read(authProvider).user!;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'tripId':         _trip!.id,
        'stationId':      user.stationId,
        'paymentMethod':  'CASH',
        'passengerCount': _pax,
        'seatNumbers':    <String>[],
      };
      final phone = _phoneCtrl.text.trim();
      if (phone.isNotEmpty) payload['phone'] = phone;

      final res = await dio.post('/bookings/guichet', data: payload);
      setState(() {
        _success = true;
        _result  = extractData(res.data);
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _phoneCtrl.clear();
    setState(() {
      _trip    = null;
      _pax     = 1;
      _success = false;
      _result  = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    if (_success) {
      return _SuccessView(
        result: _result!,
        trip:   _trip!,
        pax:    _pax,
        onReset: _reset,
      );
    }

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

                  // ── Sélection du voyage ──────────────────────────────────
                  _Label(l10n.quickSaleSelectTrip),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (_, ref, _) {
                      final async = ref.watch(_quickTripsProvider);
                      return async.when(
                        loading: () => AppShimmer.tripCards(count: 3),
                        error: (e, _) => Text('${l10n.error}: $e',
                            style: const TextStyle(color: Color(0xFFDC2626))),
                        data: (trips) {
                          if (trips.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(l10n.guichetNoTripsAvailable,
                                  style: TextStyle(color: context.textMuted)),
                            );
                          }

                          // Signaler si des voyages avec gestion avancée des sièges
                          // ne peuvent pas être vendus ici
                          final asmOnly = trips.every((t) => t.advancedSeatManagement);
                          if (asmOnly) {
                            return _AsmBanner(onGuichet: () {
                              context.pop();
                              context.go('/agent/guichet');
                            });
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...trips.map((t) {
                                // Voyages avec sièges numérotés : renvoi vers guichet
                                if (t.advancedSeatManagement) {
                                  return _AsmTripTile(t, onGuichet: () {
                                    context.pop();
                                    context.go('/agent/guichet');
                                  });
                                }

                                final full  = t.availableSeats == 0;
                                final sel   = _trip?.id == t.id;
                                final pct   = t.totalSeats > 0
                                    ? (t.totalSeats - t.availableSeats) / t.totalSeats
                                    : 0.0;

                                return GestureDetector(
                                  onTap: full ? null : () => setState(() {
                                    _trip = t;
                                    _pax  = 1;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: full
                                          ? context.inputFill
                                          : sel ? brandOrange : context.cardBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: full
                                            ? context.divider
                                            : sel ? brandOrange : context.divider,
                                        width: sel ? 0 : 1,
                                      ),
                                      boxShadow: sel ? [
                                        BoxShadow(
                                          color: brandOrange.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ] : [],
                                    ),
                                    child: Row(
                                      children: [
                                        // Heure + classe
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat('HH:mm').format(t.departureAt.toLocal()),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: full
                                                    ? context.textMuted
                                                    : sel ? Colors.white : brandOrange,
                                              ),
                                            ),
                                            Text(
                                              t.tripClass,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: full
                                                    ? context.textMuted
                                                    : sel ? Colors.white70 : context.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        // Destination + barre
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.destinationCity,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: full
                                                      ? context.textMuted
                                                      : sel ? Colors.white : context.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(3),
                                                child: LinearProgressIndicator(
                                                  value: pct,
                                                  backgroundColor: sel
                                                      ? Colors.white.withValues(alpha: 0.3)
                                                      : context.divider,
                                                  valueColor: AlwaysStoppedAnimation(
                                                    full
                                                        ? Colors.red
                                                        : sel
                                                            ? Colors.white
                                                            : pct > 0.8 ? Colors.red : brandOrange,
                                                  ),
                                                  minHeight: 5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                full
                                                    ? 'Complet'
                                                    : l10n.searchSeat(t.availableSeats),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: full ? FontWeight.w600 : FontWeight.normal,
                                                  color: full
                                                      ? Colors.red
                                                      : sel ? Colors.white70 : context.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Prix
                                        Text(
                                          '${t.price.toStringAsFixed(0)} F',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: full
                                                ? context.textMuted
                                                : sel ? Colors.white : brandOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  if (_trip != null) ...[
                    const SizedBox(height: 20),

                    // ── Nombre de passagers ──────────────────────────────
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
                          onTap: _pax < _trip!.availableSeats
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
                    // Raccourcis 1–5
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3, 4, 5].map((n) {
                        if (n > _trip!.availableSeats) return const SizedBox.shrink();
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
                                  color: sel ? Colors.white : context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Badge paiement espèces ───────────────────────────
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 15, color: Color(0xFF16A34A)),
                            SizedBox(width: 6),
                            Text(
                              'Espèces uniquement',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Téléphone passager (optionnel) ───────────────────
                    _Label('TÉLÉPHONE PASSAGER (optionnel)'),
                    const SizedBox(height: 8),
                    PhoneInputField(
                      controller: _phoneCtrl,
                      onChanged:  (_) => setState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.info_outline,
                          size: 13, color: context.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _phoneCtrl.text.trim().isNotEmpty
                              ? 'Le billet sera attribué au passager inscrit avec ce numéro'
                              : 'Si fourni, attribue la vente à un passager inscrit',
                          style: TextStyle(
                              fontSize: 11, color: context.textMuted),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // ── Bouton Encaisser ─────────────────────────────────────────
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
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(l10n.quickSaleCollect(
                            NumberFormat('#,###', locale)
                                .format((_trip!.price * _pax).toInt()),
                          )),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Banner : voyage ASM uniquement ───────────────────────────────────────────

class _AsmBanner extends StatelessWidget {
  final VoidCallback onGuichet;
  const _AsmBanner({required this.onGuichet});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: brandOrange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: brandOrange.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      const Icon(Icons.event_seat_outlined, color: brandOrange, size: 32),
      const SizedBox(height: 8),
      const Text(
        'Tous les voyages disponibles ont des sièges numérotés.',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const SizedBox(height: 4),
      const Text(
        'Utilisez le Guichet pour choisir les sièges.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onGuichet,
        icon: const Icon(Icons.point_of_sale_outlined, size: 16),
        label: const Text('Aller au Guichet'),
        style: OutlinedButton.styleFrom(
          foregroundColor: brandOrange,
          side: BorderSide(color: brandOrange.withValues(alpha: 0.5)),
        ),
      ),
    ]),
  );
}

// ── Tile pour voyage ASM non compatible quick-sale ───────────────────────────

class _AsmTripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onGuichet;
  const _AsmTripTile(this.trip, {required this.onGuichet});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.inputFill,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.divider),
    ),
    child: Row(
      children: [
        Text(
          DateFormat('HH:mm').format(trip.departureAt.toLocal()),
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.destinationCity,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: context.textSecondary)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.event_seat_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Sièges numérotés — Guichet requis',
                    style:
                        TextStyle(fontSize: 11, color: context.textMuted)),
              ]),
            ],
          ),
        ),
        TextButton(
          onPressed: onGuichet,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32)),
          child: const Text('Guichet', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
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
      fontSize: 12,
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

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> result;
  final Trip trip;
  final int  pax;
  final VoidCallback onReset;
  const _SuccessView({
    required this.result,
    required this.trip,
    required this.pax,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final ref   = result['reference'] as String? ?? '—';
    final total = result['totalAmount']?.toString() ?? '—';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF16A34A), size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.quickSaleSuccess,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary),
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
                child: Column(children: [
                  _InfoRow(label: l10n.bookingRef, value: ref),
                  const SizedBox(height: 8),
                  _InfoRow(label: l10n.total, value: '$total F'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: l10n.tripDeparture,
                    value: DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                  ),
                ]),
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
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
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
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: context.textPrimary)),
    ],
  );
}
