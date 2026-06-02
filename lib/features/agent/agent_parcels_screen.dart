import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/photo_capture.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _tripParcelsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, tripId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/parcels/trip/$tripId');
  final data = extractData(res.data);
  return (data as List).cast<dynamic>();
});

// ── Status config ─────────────────────────────────────────────────────────────

const _statusCfg = {
  'PENDING':    (label: 'En attente',     color: Color(0xFF9CA3AF)),
  'COLLECTED':  (label: 'Pris en charge', color: Color(0xFF3B82F6)),
  'IN_TRANSIT': (label: 'En transit',     color: Color(0xFF8B5CF6)),
  'ARRIVED':    (label: 'Arrivé',         color: Color(0xFFF59E0B)),
  'DELIVERED':  (label: 'Livré ✓',        color: Color(0xFF16A34A)),
  'RETURNED':   (label: 'Retourné',       color: Color(0xFFEF4444)),
};

// Allowed transitions for each status
const _transitions = {
  'PENDING':    ['COLLECTED', 'RETURNED'],
  'COLLECTED':  ['IN_TRANSIT', 'RETURNED'],
  'IN_TRANSIT': ['ARRIVED', 'RETURNED'],
  'ARRIVED':    ['DELIVERED', 'RETURNED'],
  'DELIVERED':  <String>[],
  'RETURNED':   <String>[],
};

// ── Screen ────────────────────────────────────────────────────────────────────

class AgentParcelsScreen extends ConsumerStatefulWidget {
  final String tripId;
  const AgentParcelsScreen({super.key, required this.tripId});

  @override
  ConsumerState<AgentParcelsScreen> createState() => _State();
}

class _State extends ConsumerState<AgentParcelsScreen> {
  bool _updating = false;

  Future<void> _changeStatus(
    Map<String, dynamic> parcel,
    String newStatus,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfirmStatusSheet(parcel: parcel, newStatus: newStatus),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updating = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/parcels/${parcel['id']}/status', data: {'status': newStatus});
      ref.invalidate(_tripParcelsProvider(widget.tripId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : ${_statusCfg[newStatus]?.label ?? newStatus}'),
          backgroundColor: _statusCfg[newStatus]?.color ?? brandOrange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tripParcelsProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Colis du voyage'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scanner un colis',
            onPressed: () => context.push('/agent/parcel-scan/${widget.tripId}'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final is403 = e is DioException && e.response?.statusCode == 403;
          if (is403) return const _PlanUpgradePrompt();
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
                const SizedBox(height: 10),
                Text(apiErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade400)),
                TextButton(
                  onPressed: () => ref.refresh(_tripParcelsProvider(widget.tripId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        },
        data: (parcels) {
          if (parcels.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun colis sur ce voyage',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enregistrez des colis au guichet',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_tripParcelsProvider(widget.tripId)),
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parcels.length,
                  itemBuilder: (_, i) {
                    final p = parcels[i] as Map<String, dynamic>;
                    return _ParcelCard(
                      parcel: p,
                      loading: _updating,
                      onChangeStatus: (s) => _changeStatus(p, s),
                      tripId: widget.tripId,
                    );
                  },
                ),
                if (_updating)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Plan upgrade prompt ───────────────────────────────────────────────────────

class _PlanUpgradePrompt extends StatelessWidget {
  const _PlanUpgradePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: brandOrange.withValues(alpha: 0.25), width: 2),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                size: 38, color: brandOrange),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fonctionnalité Premium',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La gestion des colis est disponible à partir du plan Professional.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: brandOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandOrange.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: brandOrange),
                  const SizedBox(width: 8),
                  Text(
                    'Plans Professional & Enterprise',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: brandOrange.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Contactez votre administrateur pour\nmettre à niveau votre abonnement.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Parcel card ───────────────────────────────────────────────────────────────

class _ParcelCard extends ConsumerWidget {
  final Map<String, dynamic> parcel;
  final bool loading;
  final ValueChanged<String> onChangeStatus;
  final String tripId;
  const _ParcelCard({
    required this.parcel,
    required this.loading,
    required this.onChangeStatus,
    required this.tripId,
  });

  void _openPhotos(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ParcelPhotoSheet(parcel: parcel, tripId: tripId, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status      = parcel['status'] as String? ?? 'PENDING';
    final cfg         = _statusCfg[status] ?? _statusCfg['PENDING']!;
    final nextAllowed = (_transitions[status] ?? []).cast<String>();
    final code        = parcel['trackingCode'] as String? ?? '';
    final weight      = parcel['weightKg'];
    final fragile     = parcel['fragile'] as bool? ?? false;
    final fee         = parcel['fee'] as int? ?? 0;
    final isPaid      = parcel['isPaid'] as bool? ?? false;
    final fmtFee      = NumberFormat('#,###', 'fr_FR').format(fee);
    final photos      = (parcel['photos'] as List?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // Indicateur photos
                if (photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera, size: 13, color: context.textMuted),
                        const SizedBox(width: 3),
                        Text('${photos.length}', style: TextStyle(fontSize: 11, color: context.textMuted)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cfg.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cfg.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sender → Recipient
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text(
                  parcel['senderName'] as String? ?? '—',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 12, color: context.textMuted),
                const SizedBox(width: 6),
                Icon(Icons.location_on_outlined, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${parcel['recipientName'] ?? '—'} · ${parcel['deliveryCity'] ?? '—'}',
                    style: TextStyle(fontSize: 13, color: context.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Weight + fee
            Row(
              children: [
                Icon(Icons.scale_outlined, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text('$weight kg', style: TextStyle(fontSize: 12, color: context.textMuted)),
                const SizedBox(width: 12),
                Icon(
                  isPaid ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                  size: 13,
                  color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  '$fmtFee FCFA${isPaid ? '' : ' (non payé)'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (fragile) ...[
                  const SizedBox(width: 8),
                  const Text('⚠️', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),

            // Miniatures photos
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openPhotos(context, ref),
                child: Row(
                  children: photos.take(2).map((p) {
                    try {
                      final bytes = base64Decode(p.contains(',') ? p.split(',').last : p);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
                        ),
                      );
                    } catch (_) { return const SizedBox.shrink(); }
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action buttons + camera
            Row(
              children: [
                // Bouton photos
                OutlinedButton.icon(
                  onPressed: () => _openPhotos(context, ref),
                  icon: Icon(
                    photos.isEmpty ? Icons.add_a_photo_outlined : Icons.photo_library_outlined,
                    size: 15,
                  ),
                  label: Text(photos.isEmpty ? 'Photos' : 'Photos (${photos.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brandOrange,
                    side: BorderSide(color: brandOrange.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                // Statut transitions
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: nextAllowed.map((s) {
                      final sCfg = _statusCfg[s] ?? _statusCfg['PENDING']!;
                      final isReturn = s == 'RETURNED';
                      return OutlinedButton(
                        onPressed: loading ? null : () => onChangeStatus(s),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isReturn ? Colors.red : sCfg.color,
                          side: BorderSide(color: isReturn ? Colors.red.shade200 : sCfg.color.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: Text(isReturn ? 'Retourner' : '→ ${sCfg.label}'),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo sheet (colis) ───────────────────────────────────────────────────────

class _ParcelPhotoSheet extends StatefulWidget {
  final Map<String, dynamic> parcel;
  final String tripId;
  final WidgetRef ref;
  const _ParcelPhotoSheet({required this.parcel, required this.tripId, required this.ref});

  @override
  State<_ParcelPhotoSheet> createState() => _ParcelPhotoSheetState();
}

class _ParcelPhotoSheetState extends State<_ParcelPhotoSheet> {
  late List<String> _photos;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _photos = (widget.parcel['photos'] as List?)?.cast<String>() ?? [];
  }

  Future<void> _save() async {
    if (!_dirty) { Navigator.pop(context); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      await dio.patch('/parcels/${widget.parcel['id']}/photos', data: {'photos': _photos});
      widget.ref.invalidate(_tripParcelsProvider(widget.tripId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photos enregistrées'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(apiErrorMessage(e)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: brandOrange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photos du colis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        widget.parcel['trackingCode'] as String? ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Prenez jusqu\'à 2 photos du colis pour preuve.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            PhotoCapture(
              photos: _photos,
              onChanged: (updated) => setState(() { _photos = updated; _dirty = true; }),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer les photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm status bottom sheet ───────────────────────────────────────────────

class _ConfirmStatusSheet extends StatelessWidget {
  final Map<String, dynamic> parcel;
  final String newStatus;
  const _ConfirmStatusSheet({required this.parcel, required this.newStatus});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusCfg[newStatus] ?? _statusCfg['PENDING']!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmer le changement',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Passer le colis ${parcel['trackingCode']} en :',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                cfg.label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cfg.color),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: cfg.color),
                    child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
