import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';

// ── Status config ─────────────────────────────────────────────────────────────

const _statusCfg = {
  'PENDING':    (label: 'En attente',     color: Color(0xFF9CA3AF)),
  'COLLECTED':  (label: 'Pris en charge', color: Color(0xFF3B82F6)),
  'IN_TRANSIT': (label: 'En transit',     color: Color(0xFF8B5CF6)),
  'ARRIVED':    (label: 'Arrivé',         color: Color(0xFFF59E0B)),
  'DELIVERED':  (label: 'Livré ✓',        color: Color(0xFF16A34A)),
  'RETURNED':   (label: 'Retourné',       color: Color(0xFFEF4444)),
};

const _transitions = {
  'PENDING':    ['COLLECTED', 'RETURNED'],
  'COLLECTED':  ['IN_TRANSIT', 'RETURNED'],
  'IN_TRANSIT': ['ARRIVED', 'RETURNED'],
  'ARRIVED':    ['DELIVERED', 'RETURNED'],
  'DELIVERED':  <String>[],
  'RETURNED':   <String>[],
};

// ── Screen ────────────────────────────────────────────────────────────────────

class ParcelScanScreen extends ConsumerStatefulWidget {
  /// Optional trip context — used to refresh the trip parcel list afterwards.
  final String? tripId;
  const ParcelScanScreen({super.key, this.tripId});

  @override
  ConsumerState<ParcelScanScreen> createState() => _State();
}

class _State extends ConsumerState<ParcelScanScreen> {
  final _scanCtrl    = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _codeCtrl    = TextEditingController();
  bool _paused       = false;
  bool _loading      = false;
  bool _manualEntry  = false;
  bool _cameraGranted = false;

  Map<String, dynamic>? _parcel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkCamera() async {
    final granted = await PermissionService.hasCamera();
    if (mounted) setState(() => _cameraGranted = granted);
  }

  Future<void> _requestCamera() async {
    final granted = await PermissionService.requestCamera(context);
    if (mounted) setState(() => _cameraGranted = granted);
  }

  // ── Lookup ────────────────────────────────────────────────────────────────

  Future<void> _lookupCode(String raw) async {
    // Extract tracking code — might be a full URL like https://app.transpro.ci/parcel/TP-COL-XXX
    final code = raw.contains('/') ? raw.split('/').last.trim().toUpperCase() : raw.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() { _loading = true; _error = null; _parcel = null; });
    HapticFeedback.mediumImpact();

    try {
      final dio = ref.read(dioProvider);
      // Use the authenticated endpoint (agent) which returns full parcel detail
      final res = await dio.get('/parcels/track/$code');
      final data = extractData(res.data) as Map<String, dynamic>;
      setState(() { _parcel = data; _loading = false; _paused = true; });
      // Show the result sheet
      _showResultSheet();
    } catch (e) {
      setState(() {
        _loading = false;
        _paused  = true;
        _error   = 'Colis introuvable pour le code : $code';
      });
      HapticFeedback.vibrate();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_paused || _loading) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    setState(() => _paused = true);
    _lookupCode(raw);
  }

  void _reset() {
    setState(() {
      _paused = false;
      _parcel = null;
      _error  = null;
      _codeCtrl.clear();
    });
  }

  // ── Status update ─────────────────────────────────────────────────────────

  Future<void> _updateStatus(String parcelId, String newStatus) async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/parcels/$parcelId/status', data: {'status': newStatus});
      if (mounted) {
        Navigator.of(context).pop(); // close sheet
        final cfg = _statusCfg[newStatus]!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Statut mis à jour : ${cfg.label}'),
          backgroundColor: cfg.color,
          behavior: SnackBarBehavior.floating,
        ));
        _reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop();
        _reset();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Result bottom sheet ───────────────────────────────────────────────────

  void _showResultSheet() {
    if (_parcel == null) return;
    final p    = _parcel!;
    final pid  = p['id'] as String? ?? '';
    final status = p['status'] as String? ?? 'PENDING';
    final next = (_transitions[status] ?? []).cast<String>();
    final cfg  = _statusCfg[status] ?? _statusCfg['PENDING']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Tracking code + status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['trackingCode'] as String? ?? '—',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: cfg.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cfg.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cfg.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: cfg.color, size: 32),
              ],
            ),

            const SizedBox(height: 16),

            // Parcel summary
            _SheetRow(label: 'Description', value: p['description'] as String? ?? '—'),
            _SheetRow(label: 'Poids',       value: '${p['weightKg']} kg'),
            _SheetRow(label: 'Expéditeur',  value: p['senderName'] as String? ?? '—'),
            _SheetRow(
              label: 'Destinataire',
              value: '${p['recipientName'] ?? '—'} · ${p['deliveryCity'] ?? '—'}',
            ),
            if (p['fragile'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(children: [
                  Text('⚠️  ', style: TextStyle(fontSize: 13)),
                  Text('Fragile — manipuler avec précaution',
                    style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ]),
              ),

            const SizedBox(height: 20),

            // Action buttons — next allowed statuses
            if (next.isEmpty)
              Center(
                child: Text(
                  status == 'DELIVERED' ? 'Ce colis a été livré.' : 'Aucune action disponible.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              )
            else ...[
              Text(
                'Changer le statut',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              ...next.map((s) {
                final sCfg  = _statusCfg[s] ?? _statusCfg['PENDING']!;
                final isRet = s == 'RETURNED';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _updateStatus(pid, s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRet ? Colors.red : sCfg.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isRet ? 'Retourner à l\'expéditeur' : '→ ${sCfg.label}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () { Navigator.pop(context); _reset(); },
                child: const Text('Fermer et scanner un autre'),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    ).whenComplete(_reset);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un colis'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => setState(() => _manualEntry = !_manualEntry),
            child: Text(
              _manualEntry ? 'Scanner QR' : 'Code manuel',
              style: TextStyle(color: brandOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _manualEntry ? _buildManualEntry() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    if (!_cameraGranted) {
      return PermissionGate(
        icon: Icons.camera_alt_outlined,
        title: 'Accès à la caméra requis',
        subtitle: 'Pour scanner les QR codes des colis, TransPro a besoin d\'accéder à la caméra.',
        buttonLabel: 'Autoriser la caméra',
        iconColor: brandOrange,
        onTap: _requestCamera,
      );
    }

    return Stack(
      children: [
        MobileScanner(controller: _scanCtrl, onDetect: _onDetect),

        // QR viewfinder overlay
        CustomPaint(
          painter: _ViewfinderPainter(),
          child: const SizedBox.expand(),
        ),

        // Instructions
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_loading)
                const CircularProgressIndicator(color: Colors.white),
              if (_error != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                ),
              ] else if (!_loading)
                const Text(
                  'Pointez le QR du colis',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saisir le code de suivi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Entrez le code manuellement si le QR est illisible.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'Ex: TP-COL-LN7X-K2M9',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              suffixIcon: _codeCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _codeCtrl.clear,
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) { if (v.trim().isNotEmpty) _lookupCode(v); },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading || _codeCtrl.text.trim().isEmpty
                  ? null
                  : () => _lookupCode(_codeCtrl.text),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Rechercher le colis'),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sheet row ─────────────────────────────────────────────────────────────────

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// ── Viewfinder painter ────────────────────────────────────────────────────────

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x88000000);
    final clearPaint   = Paint()..blendMode = BlendMode.clear;
    final cornerPaint  = Paint()
      ..color       = brandOrange
      ..strokeWidth = 3.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final half = size.width * 0.33;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: half * 2, height: half * 2);
    const cr   = 16.0;
    const cLen = 28.0;

    // Dim overlay with hole
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(cr)), clearPaint);
    canvas.restore();

    // Corner marks
    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;

    for (final corner in [(tl, true, true), (tr, false, true), (bl, true, false), (br, false, false)]) {
      final (c, isLeft, isTop) = corner;
      final dx = isLeft ?  1 : -1;
      final dy = isTop  ?  1 : -1;
      canvas.drawLine(c, c + Offset(dx * cLen, 0), cornerPaint);
      canvas.drawLine(c, c + Offset(0, dy * cLen), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
