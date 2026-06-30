import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Récupère un billet public par sa référence (vente guichet, lien SMS).
final _publicTicketProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, reference) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/bookings/public/$reference');
  return Map<String, dynamic>.from(extractData(res.data) as Map);
});

class TicketRetrievalScreen extends ConsumerWidget {
  final String reference;
  const TicketRetrievalScreen({super.key, required this.reference});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_publicTicketProvider(reference));
    return Scaffold(
      appBar: AppBar(title: const Text('Mon billet')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: apiErrorMessage(e, fallback: 'Billet introuvable. Vérifiez la référence.'),
          onRetry: () => ref.invalidate(_publicTicketProvider(reference)),
        ),
        data: (data) => _TicketView(data: data),
      ),
    );
  }
}

class _TicketView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TicketView({required this.data});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final trip   = (data['trip'] as Map?) ?? const {};
    final tickets = (data['tickets'] as List?) ?? const [];
    final ref     = data['reference'] as String? ?? '—';
    final depAt   = trip['departureAt'] != null ? DateTime.tryParse('${trip['departureAt']}') : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Carte trajet ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${trip['originCity'] ?? '—'}',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary)),
                        Row(children: [
                          Icon(Icons.arrow_forward, size: 13, color: brandOrange),
                          const SizedBox(width: 4),
                          Text('${trip['destinationCity'] ?? '—'}',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: brandOrange)),
                        ]),
                      ],
                    ),
                  ),
                  if (depAt != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(DateFormat('HH:mm').format(depAt.toLocal()),
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900, color: brandOrange)),
                      Text(DateFormat('EEE d MMM', locale).format(depAt.toLocal()),
                          style: TextStyle(fontSize: 11, color: context.textMuted)),
                    ]),
                ],
              ),
              const SizedBox(height: 14),
              _Row(label: 'Référence', value: ref, mono: true),
              if ((data['seatNumbers'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                _Row(label: 'Sièges', value: (data['seatNumbers'] as List).join(', ')),
              ],
              if (trip['departureStation'] != null) ...[
                const SizedBox(height: 8),
                _Row(label: 'Gare de départ', value: '${trip['departureStation']}'),
              ],
              if (trip['companyName'] != null) ...[
                const SizedBox(height: 8),
                _Row(label: 'Compagnie', value: '${trip['companyName']}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── QR code(s) ───────────────────────────────────────────────────
        ...tickets.asMap().entries.map((e) {
          final t = e.value as Map;
          final qrData = t['qrCodeData'] as String? ?? t['qrCode'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.divider),
            ),
            child: Column(children: [
              Text(
                tickets.length > 1
                    ? 'Billet ${e.key + 1}/${tickets.length}${t['seatNumber'] != null ? ' — Siège ${t['seatNumber']}' : ''}'
                    : 'Votre billet',
                style: TextStyle(fontWeight: FontWeight.w700, color: context.textSecondary),
              ),
              const SizedBox(height: 12),
              if (qrData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: QrImageView(data: qrData, size: 200),
                )
              else
                Text('QR indisponible — présentez la référence.',
                    style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 8),
              Text('Présentez ce QR à l\'embarquement',
                  style: TextStyle(fontSize: 11, color: context.textMuted)),
            ]),
          );
        }),

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            final link = '$kPublicWebUrl/ticket/$ref';
            Share.share('Mon billet — Réf $ref\n$link');
          },
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Partager'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _Row({required this.label, required this.value, this.mono = false});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: TextStyle(color: context.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.textPrimary,
                fontFamily: mono ? 'monospace' : null,
              )),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ]),
        ),
      );
}
