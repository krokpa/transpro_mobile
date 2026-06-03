import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _sentParcelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/parcels/my');
  return (extractData(res.data) as List).cast<dynamic>();
});

final _receivedParcelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ref.read(dioProvider).get('/parcels/my/received');
  return (extractData(res.data) as List).cast<dynamic>();
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

const _progressSteps = ['PENDING', 'COLLECTED', 'IN_TRANSIT', 'ARRIVED', 'DELIVERING', 'DELIVERED'];

// ── Screen ────────────────────────────────────────────────────────────────────

class MyParcelsScreen extends ConsumerStatefulWidget {
  const MyParcelsScreen({super.key});

  @override
  ConsumerState<MyParcelsScreen> createState() => _MyParcelsScreenState();
}

class _MyParcelsScreenState extends ConsumerState<MyParcelsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sent     = ref.watch(_sentParcelsProvider);
    final received = ref.watch(_receivedParcelsProvider);

    final sentCount = sent.valueOrNull?.length ?? 0;
    final recvCount = received.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes colis'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Suivre un colis',
            onPressed: () => _tabs.animateTo(2),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Envoyer un colis',
            onPressed: () => context.push('/passenger/parcels/send'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: sentCount > 0 ? 'Envoyés ($sentCount)' : 'Envoyés'),
            Tab(text: recvCount > 0 ? 'Reçus ($recvCount)'   : 'Reçus'),
            const Tab(text: 'Suivre'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Envoyés ──────────────────────────────────────────────────────
          _ParcelList(
            async: sent,
            role: _Role.sent,
            onRefresh: () => ref.refresh(_sentParcelsProvider),
            emptyTitle: 'Aucun colis envoyé',
            emptyBody: 'Vos colis expédiés via TransPro CI\napparaîtront ici.',
          ),

          // ── Reçus ────────────────────────────────────────────────────────
          _ParcelList(
            async: received,
            role: _Role.received,
            onRefresh: () => ref.refresh(_receivedParcelsProvider),
            emptyTitle: 'Aucun colis reçu',
            emptyBody: 'Les colis dont vous êtes destinataire\napparaîtront ici.',
          ),

          // ── Suivre ───────────────────────────────────────────────────────
          const _TrackTab(),
        ],
      ),
    );
  }
}

// ── Parcel list ───────────────────────────────────────────────────────────────

enum _Role { sent, received }

class _ParcelList extends StatelessWidget {
  final AsyncValue<List<dynamic>> async;
  final _Role role;
  final VoidCallback onRefresh;
  final String emptyTitle;
  final String emptyBody;

  const _ParcelList({
    required this.async,
    required this.role,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyBody,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => AppShimmer.parcelTiles(),
      error:   (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: context.textMuted, size: 40),
          const SizedBox(height: 10),
          Text('Erreur de chargement', style: TextStyle(color: context.textSecondary)),
          TextButton(onPressed: onRefresh, child: const Text('Réessayer')),
        ]),
      ),
      data: (parcels) => parcels.isEmpty
          ? _EmptyState(title: emptyTitle, body: emptyBody)
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: parcels.length,
                itemBuilder: (_, i) => _ParcelCard(
                  parcel: parcels[i] as Map<String, dynamic>,
                  role:   role,
                ),
              ),
            ),
    );
  }
}

// ── Track tab ─────────────────────────────────────────────────────────────────

class _TrackTab extends StatelessWidget {
  const _TrackTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.qr_code_2_rounded, size: 56, color: context.textMuted),
          const SizedBox(height: 16),
          Text(
            'Suivre un colis',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entrez le code de suivi ou scannez le QR code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.textMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/parcel'),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Ouvrir le suivi'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String title;
  final String body;
  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 56, color: context.textMuted),
      const SizedBox(height: 12),
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        body,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: context.textMuted),
      ),
    ]),
  );
}

// ── Parcel card ───────────────────────────────────────────────────────────────

class _ParcelCard extends ConsumerWidget {
  final Map<String, dynamic> parcel;
  final _Role role;
  const _ParcelCard({required this.parcel, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status    = parcel['status']    as String? ?? 'PENDING';
    final cfg       = _statusCfg[status] ?? _statusCfg['PENDING']!;
    final code      = parcel['trackingCode'] as String? ?? '';
    final dest      = parcel['deliveryCity'] as String? ?? '—';
    final createdAt = parcel['createdAt'] as String?;
    final fee       = parcel['fee'] as int? ?? 0;

    // Affiche le nom de l'autre partie selon le rôle
    final otherName = role == _Role.sent
        ? parcel['recipientName'] as String? ?? '—'
        : parcel['senderName']    as String? ?? '—';
    final otherLabel = role == _Role.sent ? 'Pour' : 'De';

    final dateFmt = createdAt != null
        ? DateFormat("d MMM yyyy", 'fr_FR').format(DateTime.parse(createdAt).toLocal())
        : '';
    final fmtFee = NumberFormat('#,###', 'fr_FR').format(fee);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/parcel/$code'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header : code + badge rôle + badge statut
            Row(children: [
              Expanded(
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // Badge rôle
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (role == _Role.received
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF9CA3AF))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role == _Role.received ? 'Reçu' : 'Envoyé',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: role == _Role.received
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              // Badge statut
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
            ]),
            const SizedBox(height: 8),

            // Destination + interlocuteur
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$dest · $otherLabel : $otherName',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),

            // Progression
            _MiniProgress(status: status),
            const SizedBox(height: 8),

            // CTA livraison à domicile
            if (status == 'ARRIVED' || status == 'DELIVERING') ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => context.push('/delivery-request/${Uri.encodeComponent(code)}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.home_outlined, size: 14, color: Color(0xFFF97316)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      status == 'DELIVERING'
                          ? 'En cours de livraison à domicile'
                          : 'Demander la livraison à domicile',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    const Icon(Icons.chevron_right, size: 14, color: Color(0xFFF97316)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Date + frais
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: context.textMuted),
              const SizedBox(width: 4),
              Text(dateFmt, style: TextStyle(fontSize: 12, color: context.textMuted)),
              const Spacer(),
              if (fee > 0)
                Text(
                  '$fmtFee FCFA',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: brandOrange,
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Mini progress ─────────────────────────────────────────────────────────────

class _MiniProgress extends StatelessWidget {
  final String status;
  const _MiniProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'RETURNED') {
      return Row(children: [
        const Icon(Icons.undo_outlined, size: 12, color: Color(0xFFEF4444)),
        const SizedBox(width: 4),
        const Text(
          'Retourné à l\'expéditeur',
          style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
        ),
      ]);
    }

    final idx      = _progressSteps.indexOf(status).clamp(0, _progressSteps.length - 1);
    final progress = idx / (_progressSteps.length - 1);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value:           progress,
          backgroundColor: context.divider,
          valueColor:      AlwaysStoppedAnimation<Color>(
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
    ]);
  }
}
