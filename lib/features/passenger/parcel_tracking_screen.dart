import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _parcelProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, code) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/parcels/track/$code');
  return extractData(res.data) as Map<String, dynamic>;
});

// ── Status config ─────────────────────────────────────────────────────────────

const _statusCfg = {
  'PENDING':    (label: 'En attente',     color: Color(0xFF9CA3AF), icon: Icons.access_time),
  'COLLECTED':  (label: 'Pris en charge', color: Color(0xFF3B82F6), icon: Icons.inventory_2_outlined),
  'IN_TRANSIT': (label: 'En transit',     color: Color(0xFF8B5CF6), icon: Icons.local_shipping_outlined),
  'ARRIVED':    (label: 'Arrivé',         color: Color(0xFFF59E0B), icon: Icons.location_on_outlined),
  'DELIVERING': (label: 'En livraison',   color: Color(0xFFEA580C), icon: Icons.local_shipping_rounded),
  'DELIVERED':  (label: 'Livré ✓',        color: Color(0xFF16A34A), icon: Icons.check_circle_outline),
  'RETURNED':   (label: 'Retourné',       color: Color(0xFFEF4444), icon: Icons.undo_outlined),
};

const _steps = ['PENDING', 'COLLECTED', 'IN_TRANSIT', 'ARRIVED', 'DELIVERED'];

// ── Screen ────────────────────────────────────────────────────────────────────

class ParcelTrackingScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  const ParcelTrackingScreen({super.key, this.initialCode});

  @override
  ConsumerState<ParcelTrackingScreen> createState() => _State();
}

class _State extends ConsumerState<ParcelTrackingScreen> {
  final _ctrl = TextEditingController();
  String? _code;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _ctrl.text = widget.initialCode!;
      _code = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search() {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de colis'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Container(
            color: context.cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Ex: TP-COL-ABC123',
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Rechercher'),
                ),
              ],
            ),
          ),

          // ── Result ────────────────────────────────────────────────────────
          Expanded(
            child: _code == null
                ? _EmptyPrompt()
                : _ParcelResult(code: _code!),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 56, color: context.textMuted),
        const SizedBox(height: 12),
        Text(
          'Entrez votre code de suivi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Le code est fourni lors de l\'envoi du colis',
          style: TextStyle(fontSize: 13, color: context.textMuted),
        ),
      ],
    ),
  );
}

// ── Parcel result ─────────────────────────────────────────────────────────────

class _ParcelResult extends ConsumerWidget {
  final String code;
  const _ParcelResult({required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_parcelProvider(code));
    return async.when(
      loading: () => AppShimmer.listTiles(count: 4),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Colis introuvable',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vérifiez votre code de suivi',
              style: TextStyle(fontSize: 13, color: context.textMuted),
            ),
          ],
        ),
      ),
      data: (data) => _ParcelDetail(data: data),
    );
  }
}

// ── Detail ────────────────────────────────────────────────────────────────────

class _ParcelDetail extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ParcelDetail({required this.data});

  String _fmt(String? iso) {
    if (iso == null) return '—';
    return DateFormat("d MMM yyyy 'à' HH:mm", 'fr_FR').format(DateTime.parse(iso).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final status    = data['status'] as String? ?? 'PENDING';
    final cfg       = _statusCfg[status] ?? _statusCfg['PENDING']!;
    final code      = data['trackingCode'] as String? ?? '';
    final route     = data['trip']?['route'];
    final origin    = route?['originCity']?['name'] as String? ?? '—';
    final dest      = route?['destinationCity']?['name'] as String? ?? '—';
    final depAt     = data['trip']?['departureAt'] as String?;

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status card ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cfg.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cfg.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copié'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              code,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 13, color: context.textMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Progress stepper ──────────────────────────────────────────────
          if (status != 'RETURNED') _ProgressStepper(currentStatus: status),

          const SizedBox(height: 16),

          // ── Info card ─────────────────────────────────────────────────────
          _InfoCard(
            title: 'Informations du colis',
            rows: [
              ('Trajet', '$origin → $dest'),
              if (depAt != null) ('Départ bus', _fmt(depAt)),
              ('Destination', data['deliveryCity'] as String? ?? '—'),
              ('Description', data['description'] as String? ?? '—'),
              ('Poids', '${data['weightKg']} kg'),
              if (data['fragile'] == true) ('Fragile', '⚠️ Oui'),
            ],
          ),

          const SizedBox(height: 12),

          // ── Timeline card ─────────────────────────────────────────────────
          _InfoCard(
            title: 'Historique',
            rows: [
              ('Enregistré',    _fmt(data['createdAt'] as String?)),
              if (data['collectedAt'] != null) ('Pris en charge', _fmt(data['collectedAt'] as String?)),
              if (data['departedAt']  != null) ('En transit',     _fmt(data['departedAt']  as String?)),
              if (data['arrivedAt']   != null) ('Arrivé',         _fmt(data['arrivedAt']   as String?)),
              if (data['deliveredAt'] != null) ('Livré',          _fmt(data['deliveredAt'] as String?)),
              if (data['returnedAt']  != null) ('Retourné',       _fmt(data['returnedAt']  as String?)),
            ],
          ),

          // ── Home delivery CTA ─────────────────────────────────────────────
          if (status == 'ARRIVED' || status == 'DELIVERING') ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => context.push(
                '/delivery-request/${Uri.encodeComponent(code)}',
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.home_outlined, color: Color(0xFFF97316), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      status == 'DELIVERING' ? 'Suivi de livraison à domicile' : 'Demander la livraison à domicile',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      status == 'DELIVERING'
                          ? 'Votre colis est en route vers vous'
                          : 'Votre colis est arrivé à la gare — faites-le livrer',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFA16207)),
                    ),
                  ])),
                  const Icon(Icons.chevron_right, color: Color(0xFFF97316), size: 20),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Progress stepper ──────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  final String currentStatus;
  const _ProgressStepper({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexOf(currentStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIdx = i ~/ 2;
            final done = stepIdx < currentIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? brandOrange : context.divider,
              ),
            );
          }
          // Dot
          final stepIdx = i ~/ 2;
          final cfg = _statusCfg[_steps[stepIdx]]!;
          final isDone    = stepIdx < currentIdx;
          final isCurrent = stepIdx == currentIdx;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? cfg.color
                      : isDone
                          ? brandOrange
                          : context.inputFill,
                  border: Border.all(
                    color: isCurrent ? cfg.color : isDone ? brandOrange : context.divider,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCurrent || isDone ? cfg.icon : Icons.circle,
                  size: isCurrent || isDone ? 16 : 6,
                  color: isCurrent || isDone ? Colors.white : context.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusCfg[_steps[stepIdx]]!.label.split(' ').first,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isCurrent ? cfg.color : context.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  r.$1,
                  style: TextStyle(fontSize: 13, color: context.textMuted),
                ),
              ),
              Expanded(
                child: Text(
                  r.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    ),
  );
}
