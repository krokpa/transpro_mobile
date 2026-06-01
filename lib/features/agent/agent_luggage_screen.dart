import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/photo_capture.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _tripLuggageProvider = FutureProvider.autoDispose
    .family<List<BookingLuggage>, String>((ref, tripId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/luggage/trip/$tripId');
  final items = extractData(res.data) as List;
  return items.map((e) => BookingLuggage.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Status config ─────────────────────────────────────────────────────────────

const _bagStatusCfg = {
  'DECLARED':  (label: 'Déclaré',   color: Color(0xFF6B7280)),
  'LOADED':    (label: 'En soute',  color: Color(0xFF3B82F6)),
  'ARRIVED':   (label: 'Arrivé',    color: Color(0xFFF59E0B)),
  'CLAIMED':   (label: 'Récupéré',  color: Color(0xFF16A34A)),
  'MISSING':   (label: 'Manquant',  color: Color(0xFFEF4444)),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class AgentLuggageScreen extends ConsumerStatefulWidget {
  final String tripId;
  const AgentLuggageScreen({super.key, required this.tripId});

  @override
  ConsumerState<AgentLuggageScreen> createState() => _State();
}

class _State extends ConsumerState<AgentLuggageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _scanning      = false;
  bool _scanPaused    = false;
  bool _processing    = false;
  String? _scanResult;
  bool _scanOk        = false;
  Map<String, dynamic>? _scannedBooking;

  final _scanCtrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanPaused || _processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final code = raw.trim().toUpperCase();
    if (!code.startsWith('LG-')) return; // Only luggage QR codes
    setState(() { _scanPaused = true; _processing = true; _scanResult = null; });
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/luggage/scan', data: { 'qrCode': code });
      final data = extractData(res.data) as Map<String, dynamic>;
      setState(() {
        _scanOk = true;
        _scanResult = code;
        _scannedBooking = data['booking'] as Map<String, dynamic>?;
      });
      HapticFeedback.mediumImpact();
      ref.invalidate(_tripLuggageProvider(widget.tripId));
    } catch (e) {
      setState(() { _scanOk = false; _scanResult = code; });
      HapticFeedback.vibrate();
    } finally {
      if (mounted) setState(() => _processing = false);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() { _scanPaused = false; _scanResult = null; });
    }
  }

  void _reset() => setState(() { _scanPaused = false; _scanResult = null; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bagages du voyage'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: brandOrange,
          labelColor: brandOrange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.list_rounded), text: 'Déclarations'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scanner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DeclarationList(tripId: widget.tripId),
          _ScannerTab(
            scanCtrl: _scanCtrl,
            onDetect: _onDetect,
            scanning: _scanning,
            paused: _scanPaused,
            processing: _processing,
            scanResult: _scanResult,
            scanOk: _scanOk,
            scannedBooking: _scannedBooking,
            onReset: _reset,
          ),
        ],
      ),
    );
  }
}

// ── Declaration list ──────────────────────────────────────────────────────────

class _DeclarationList extends ConsumerWidget {
  final String tripId;
  const _DeclarationList({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_tripLuggageProvider(tripId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(apiErrorMessage(e))),
      data: (luggage) {
        if (luggage.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.luggage_outlined, size: 52, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Aucun bagage déclaré pour ce voyage',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ]),
          );
        }
        final totalBags    = luggage.fold(0, (s, l) => s + l.bagCount);
        final loadedBags   = luggage.fold(0, (s, l) => s + l.bags.where((b) => b.status == 'LOADED').length);
        final missingBags  = luggage.fold(0, (s, l) => s + l.bags.where((b) => b.status == 'MISSING').length);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_tripLuggageProvider(tripId).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI chips
              Row(children: [
                _Chip(label: 'Total',    value: '$totalBags sacs',  color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                _Chip(label: 'En soute', value: '$loadedBags',      color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                if (missingBags > 0)
                  _Chip(label: 'Manquants', value: '$missingBags', color: const Color(0xFFEF4444)),
              ]),
              const SizedBox(height: 16),
              ...luggage.map((l) => _LuggageCard(luggage: l, tripId: tripId)),
            ],
          ),
        );
      },
    );
  }
}

class _LuggageCard extends ConsumerWidget {
  final BookingLuggage luggage;
  final String tripId;
  const _LuggageCard({required this.luggage, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_outline, color: brandOrange, size: 20),
        ),
        title: Text(
          '${luggage.bagCount} sac(s) · ${luggage.totalWeightKg} kg',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: luggage.excessFeeXof > 0
            ? Text(
                'Excédent ${luggage.excessWeightKg.toStringAsFixed(1)} kg — ${luggage.excessFeeXof} FCFA'
                '${luggage.excessPaid ? ' ✓' : ' (impayé)'}',
                style: TextStyle(
                  fontSize: 12,
                  color: luggage.excessPaid ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                ),
              )
            : null,
        children: [
          if (luggage.bags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun sac', style: TextStyle(color: Colors.grey)),
            )
          else
            ...luggage.bags.map((bag) => _BagTile(bag: bag, tripId: tripId, ref: ref)),
        ],
      ),
    );
  }
}

class _BagTile extends StatelessWidget {
  final LuggageBag bag;
  final String tripId;
  final WidgetRef ref;
  const _BagTile({required this.bag, required this.tripId, required this.ref});

  void _openPhotos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BagPhotoSheet(bag: bag, tripId: tripId, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _bagStatusCfg[bag.status] ?? _bagStatusCfg['DECLARED']!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.luggage, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bag.label ?? 'Sac',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(bag.qrCode,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              // Indicateur photos
              if (bag.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_camera, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text('${bag.photos.length}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ]),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cfg.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(cfg.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cfg.color)),
              ),
            ],
          ),
          // Miniatures photos
          if (bag.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openPhotos(context),
              child: Row(
                children: bag.photos.take(2).map((p) {
                  try {
                    final bytes = base64Decode(p.contains(',') ? p.split(',').last : p);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
                      ),
                    );
                  } catch (_) { return const SizedBox.shrink(); }
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Bouton photos
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPhotos(context),
              icon: Icon(
                bag.photos.isEmpty ? Icons.add_a_photo_outlined : Icons.photo_library_outlined,
                size: 14,
              ),
              label: Text(bag.photos.isEmpty ? 'Prendre des photos' : 'Photos (${bag.photos.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandOrange,
                side: BorderSide(color: brandOrange.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

// ── Photo sheet (sac de bagage) ───────────────────────────────────────────────

class _BagPhotoSheet extends StatefulWidget {
  final LuggageBag bag;
  final String tripId;
  final WidgetRef ref;
  const _BagPhotoSheet({required this.bag, required this.tripId, required this.ref});

  @override
  State<_BagPhotoSheet> createState() => _BagPhotoSheetState();
}

class _BagPhotoSheetState extends State<_BagPhotoSheet> {
  late List<String> _photos;
  bool _saving = false;
  bool _dirty  = false;

  @override
  void initState() {
    super.initState();
    _photos = [...widget.bag.photos];
  }

  Future<void> _save() async {
    if (!_dirty) { Navigator.pop(context); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      await dio.patch('/luggage/bags/${widget.bag.id}/photos', data: {'photos': _photos});
      widget.ref.invalidate(_tripLuggageProvider(widget.tripId));
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
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.luggage, color: Color(0xFF0EA5E9), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photos du sac', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        widget.bag.label ?? widget.bag.qrCode,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Prenez jusqu\'à 2 photos du sac pour documenter son état.',
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

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
    ]),
  );
}

// ── Scanner tab ───────────────────────────────────────────────────────────────

class _ScannerTab extends StatelessWidget {
  final MobileScannerController scanCtrl;
  final void Function(BarcodeCapture) onDetect;
  final bool scanning, paused, processing;
  final String? scanResult;
  final bool scanOk;
  final Map<String, dynamic>? scannedBooking;
  final VoidCallback onReset;

  const _ScannerTab({
    required this.scanCtrl,
    required this.onDetect,
    required this.scanning,
    required this.paused,
    required this.processing,
    required this.scanResult,
    required this.scanOk,
    required this.scannedBooking,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MobileScanner(controller: scanCtrl, onDetect: onDetect),

      // Overlay with result
      Positioned(
        bottom: 40,
        left: 16,
        right: 16,
        child: Column(children: [
          if (processing)
            const CircularProgressIndicator(color: Colors.white),
          if (scanResult != null && !processing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scanOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Icon(
                  scanOk ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white, size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  scanOk ? 'Sac scanné avec succès' : 'Code invalide ou non reconnu',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(scanResult!,
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12)),
                if (scanOk && scannedBooking != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Réservation : ${scannedBooking!['reference']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Scanner un autre', style: TextStyle(color: Colors.white)),
                ),
              ]),
            )
          else if (scanResult == null && !processing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scannez l\'étiquette QR d\'un sac (code LG-...)',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
        ]),
      ),
    ]);
  }
}
