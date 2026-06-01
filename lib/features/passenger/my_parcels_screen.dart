import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _myParcelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/parcels/my');
  final items = extractData(res.data);
  return (items as List).cast<dynamic>();
});

// ── Status config ─────────────────────────────────────────────────────────────

const _statusCfg = {
  'PENDING':    (label: 'En attente',     color: Color(0xFF9CA3AF)),
  'COLLECTED':  (label: 'Pris en charge', color: Color(0xFF3B82F6)),
  'IN_TRANSIT': (label: 'En transit',     color: Color(0xFF8B5CF6)),
  'ARRIVED':    (label: 'Arrivé',         color: Color(0xFFF59E0B)),
  'DELIVERING': (label: 'En livraison',   color: Color(0xFFEA580C)),
  'DELIVERED':  (label: 'Livré',          color: Color(0xFF16A34A)),
  'RETURNED':   (label: 'Retourné',       color: Color(0xFFEF4444)),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class MyParcelsScreen extends ConsumerWidget {
  const MyParcelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myParcelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes colis envoyés'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Suivre un colis',
            onPressed: () => context.push('/parcel'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Envoyer un colis',
            onPressed: () => context.push('/passenger/parcels/send'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.textMuted, size: 40),
              const SizedBox(height: 10),
              Text('Erreur de chargement', style: TextStyle(color: context.textSecondary)),
              TextButton(
                onPressed: () => ref.refresh(_myParcelsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (parcels) => parcels.isEmpty
            ? _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(_myParcelsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parcels.length,
                  itemBuilder: (_, i) => _ParcelCard(parcel: parcels[i] as Map<String, dynamic>),
                ),
              ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 56, color: context.textMuted),
        const SizedBox(height: 12),
        Text(
          'Aucun colis envoyé',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Vos colis expédiés via TransPro CI\napparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.textMuted),
        ),
      ],
    ),
  );
}

// ── Parcel card ───────────────────────────────────────────────────────────────

class _ParcelCard extends ConsumerWidget {
  final Map<String, dynamic> parcel;
  const _ParcelCard({required this.parcel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = parcel['status'] as String? ?? 'PENDING';
    final cfg    = _statusCfg[status] ?? _statusCfg['PENDING']!;
    final code   = parcel['trackingCode'] as String? ?? '';
    final dest   = parcel['deliveryCity'] as String? ?? '—';
    final recipient = parcel['recipientName'] as String? ?? '—';
    final createdAt = parcel['createdAt'] as String?;
    final fee    = parcel['fee'] as int? ?? 0;

    String dateFmt = '';
    if (createdAt != null) {
      dateFmt = DateFormat("d MMM yyyy", 'fr_FR').format(DateTime.parse(createdAt).toLocal());
    }

    final fmtFee = NumberFormat('#,###', 'fr_FR').format(fee);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/parcel/$code'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: code + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cfg.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cfg.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cfg.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Destination + recipient
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: context.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$dest · à $recipient',
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Mini progress bar
              _MiniProgress(status: status),
              const SizedBox(height: 8),
              // Home delivery CTA for ARRIVED/DELIVERING
              if (status == 'ARRIVED' || status == 'DELIVERING') ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/delivery-request/${Uri.encodeComponent(code)}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.home_outlined, size: 14, color: Color(0xFFF97316)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        status == 'DELIVERING'
                            ? 'En cours de livraison à domicile'
                            : 'Demander la livraison à domicile',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      )),
                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFFF97316)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Date + fee
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    dateFmt,
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    '$fmtFee FCFA',
                    style: const TextStyle(
                      fontSize: 13,
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
    );
  }
}

// ── Mini progress ─────────────────────────────────────────────────────────────

const _progressSteps = ['PENDING', 'COLLECTED', 'IN_TRANSIT', 'ARRIVED', 'DELIVERING', 'DELIVERED'];

class _MiniProgress extends StatelessWidget {
  final String status;
  const _MiniProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'RETURNED') {
      return Row(
        children: [
          const Icon(Icons.undo_outlined, size: 12, color: Color(0xFFEF4444)),
          const SizedBox(width: 4),
          Text(
            'Retourné à l\'expéditeur',
            style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final currentIdx = _progressSteps.indexOf(status).clamp(0, _progressSteps.length - 1);
    final total = _progressSteps.length - 1;
    final progress = currentIdx / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              status == 'DELIVERED' ? const Color(0xFF16A34A) : brandOrange,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${(progress * 100).toInt()}% — ${_statusCfg[status]?.label ?? status}',
          style: TextStyle(fontSize: 10, color: context.textMuted),
        ),
      ],
    );
  }
}
