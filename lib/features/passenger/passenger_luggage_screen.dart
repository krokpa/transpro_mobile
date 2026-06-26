import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _luggageProvider = FutureProvider.autoDispose
    .family<BookingLuggage?, String>((ref, bookingId) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/luggage/my/$bookingId');
    final data = extractData(res.data);
    if (data == null) return null;
    return BookingLuggage.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// ── Status config ─────────────────────────────────────────────────────────────

const _bagCfg = {
  'DECLARED':  (label: 'Déclaré au guichet', color: Color(0xFF6B7280), icon: Icons.access_time_rounded),
  'LOADED':    (label: 'Chargé en soute',    color: Color(0xFF3B82F6), icon: Icons.upload_rounded),
  'ARRIVED':   (label: 'Arrivé à destination',color: Color(0xFFF59E0B), icon: Icons.location_on_rounded),
  'CLAIMED':   (label: 'Récupéré ✓',         color: Color(0xFF16A34A), icon: Icons.check_circle_rounded),
  'MISSING':   (label: 'Signalé manquant',    color: Color(0xFFEF4444), icon: Icons.warning_rounded),
};

const _bagSteps = ['DECLARED', 'LOADED', 'ARRIVED', 'CLAIMED'];

// ── Screen ────────────────────────────────────────────────────────────────────

class PassengerLuggageScreen extends ConsumerWidget {
  final String bookingId;
  final String bookingRef;

  const PassengerLuggageScreen({
    super.key,
    required this.bookingId,
    required this.bookingRef,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_luggageProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes bagages'),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(count: 3),
        error: (_, _) => const Center(child: Text('Erreur lors du chargement')),
        data: (luggage) {
          if (luggage == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.luggage_outlined, size: 52, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Aucun bagage déclaré',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'L\'agent peut déclarer vos bagages au guichet\navant le départ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_luggageProvider(bookingId).future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Summary card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C1425), Color(0xFF1A3A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const Icon(Icons.luggage, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${luggage.bagCount} sac${luggage.bagCount > 1 ? 's' : ''} enregistré${luggage.bagCount > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${luggage.totalWeightKg} kg total · franchise ${luggage.freeWeightKg} kg',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ])),
                    if (luggage.excessFeeXof > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: luggage.excessPaid
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(children: [
                          Text(
                            '${luggage.excessFeeXof} FCFA',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          Text(
                            luggage.excessPaid ? 'Payé' : 'Excédent',
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ]),
                      ),
                  ]),
                ),

                const SizedBox(height: 20),

                Text(
                  'VOS SACS',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey[500], letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // Individual bags
                ...luggage.bags.map((bag) {
                  final cfg = _bagCfg[bag.status] ?? _bagCfg['DECLARED']!;
                  final stepIdx = _bagSteps.indexOf(bag.status);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: cfg.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cfg.icon, color: cfg.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              bag.label ?? 'Sac',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            if (bag.weightKg != null)
                              Text(
                                '${bag.weightKg} kg',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cfg.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cfg.label,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cfg.color),
                            ),
                          ),
                        ]),

                        // Progress bar (not shown for MISSING)
                        if (bag.status != 'MISSING') ...[
                          const SizedBox(height: 14),
                          Row(
                            children: List.generate(_bagSteps.length * 2 - 1, (i) {
                              if (i.isOdd) {
                                final idx = i ~/ 2;
                                return Expanded(
                                  child: Container(
                                    height: 2,
                                    color: idx < stepIdx ? brandOrange : const Color(0xFFE2E8F0),
                                  ),
                                );
                              }
                              final idx = i ~/ 2;
                              final done    = idx < stepIdx;
                              final current = idx == stepIdx;
                              return Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? brandOrange
                                      : current
                                      ? brandOrange
                                      : const Color(0xFFE2E8F0),
                                  border: current
                                      ? Border.all(color: brandOrange.withValues(alpha: 0.3), width: 3)
                                      : null,
                                ),
                                child: done
                                    ? const Icon(Icons.check, size: 9, color: Colors.white)
                                    : null,
                              );
                            }),
                          ),
                        ],

                        // Missing note
                        if (bag.status == 'MISSING' && bag.missingNote != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.info_outline, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                bag.missingNote!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                              )),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
