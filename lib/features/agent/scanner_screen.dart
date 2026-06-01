import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/offline/manifest_cache.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  /// Optional trip context — when set, enables offline fallback for that trip.
  final String? tripId;
  const ScannerScreen({super.key, this.tripId});
  @override
  ConsumerState<ScannerScreen> createState() => _State();
}

class _State extends ConsumerState<ScannerScreen> {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _paused        = false;
  bool _loading       = false;
  bool _cameraGranted = false;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  Future<void> _checkCamera() async {
    final granted = await PermissionService.hasCamera();
    if (mounted) setState(() => _cameraGranted = granted);
  }

  Future<void> _requestCamera() async {
    final granted = await PermissionService.requestCamera(context);
    if (mounted) setState(() => _cameraGranted = granted);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_paused || _loading) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() { _paused = true; _loading = true; });
    HapticFeedback.mediumImpact();

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/payments/tickets/scan', data: {'qrData': code});
      final data = extractData(res.data);
      final booking = data['booking'];
      final user    = booking?['user'];
      final route   = booking?['trip']?['route'];
      setState(() => _result = _ScanResult(
        ok:        true,
        passenger: user != null ? '${user['firstName']} ${user['lastName']}' : '—',
        route:     route != null ? '${route['originCity']?['name']} → ${route['destinationCity']?['name']}' : '—',
        seat:      (booking?['seatNumbers'] as List?)?.join(', ') ?? '—',
        isOffline: false,
      ));
    } catch (e) {
      if (widget.tripId != null && ManifestCache.hasManifest(widget.tripId!)) {
        final match = ManifestCache.findByQrCode(widget.tripId!, code);
        if (match != null) {
          final entry   = match['entry']  as Map<String, dynamic>;
          final ticket  = match['ticket'] as Map<String, dynamic>;
          final already = ticket['checkedInAt'] != null;
          if (already) {
            HapticFeedback.vibrate();
            setState(() => _result = _ScanResult(
              ok: false,
              message: AppLocalizations.of(context).scanAlreadyBoarded,
            ));
          } else {
            await ManifestCache.queueCheckIn(ticket['id'] as String, widget.tripId!);
            HapticFeedback.mediumImpact();
            setState(() => _result = _ScanResult(
              ok:        true,
              passenger: '${entry['user']?['firstName'] ?? ''} ${entry['user']?['lastName'] ?? ''}'.trim(),
              route:     '—',
              seat:      ticket['seatNumber'] as String? ?? '—',
              isOffline: true,
            ));
          }
          return;
        }
      }
      HapticFeedback.vibrate();
      setState(() => _result = _ScanResult(
        ok: false,
        message: _extractMsg(e, context),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractMsg(dynamic e, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message']?.toString() ?? l10n.scanInvalid;
    } catch (_) {}
    return l10n.scanInvalid;
  }

  void _reset() {
    setState(() { _paused = false; _loading = false; _result = null; });
    _ctrl.start();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context);
    final hasOffline = widget.tripId != null && ManifestCache.hasManifest(widget.tripId!);

    if (!_cameraGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: PermissionGate(
          icon: Icons.camera_alt_outlined,
          title: 'Accès à la caméra requis',
          subtitle: 'Pour scanner les QR codes des billets, TransPro a besoin d\'accéder à la caméra.',
          buttonLabel: 'Autoriser la caméra',
          iconColor: brandOrange,
          onTap: _requestCamera,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (!_paused) MobileScanner(controller: _ctrl, onDetect: _onDetect),

        if (_result == null && !_loading) ...[
          Container(color: Colors.black45),
          Center(child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: brandOrange, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          )),
          Positioned(
            bottom: 140, left: 0, right: 0,
            child: Center(child: Text(l10n.scanCenterQr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14))),
          ),
          if (hasOffline)
            Positioned(
              bottom: 100, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l10n.scanOfflineMode,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              )),
            ),
          SafeArea(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.scanAgentHeader,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              Text(l10n.scanTitle,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          )),
        ],

        if (_loading) Container(
          color: Colors.black.withAlpha(153),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(l10n.scanVerifying, style: const TextStyle(color: Colors.white)),
          ])),
        ),

        if (_result != null) SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ResultCard(result: _result!, onReset: _reset),
        ))),
      ]),
    );
  }
}

class _ScanResult {
  final bool ok;
  final String? passenger;
  final String? route;
  final String? seat;
  final String? message;
  final bool isOffline;
  const _ScanResult({required this.ok, this.passenger, this.route, this.seat, this.message, this.isOffline = false});
}

class _ResultCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onReset;
  const _ResultCard({required this.result, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: result.ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          child: Row(children: [
            Icon(result.ok ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.ok ? l10n.scanValidatedLabel : l10n.scanRejectedLabel,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              if (result.ok && result.isOffline)
                Text(l10n.scanOfflineSyncNote,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: result.ok ? Column(children: [
            _Row(icon: Icons.person, label: l10n.scanPassengerLabel, value: result.passenger!),
            if (result.route != '—') _Row(icon: Icons.route, label: l10n.scanTripLabel, value: result.route!),
            _Row(icon: Icons.event_seat_outlined, label: l10n.scanSeatLabel, value: result.seat!),
          ]) : Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red[300]),
            const SizedBox(height: 8),
            Text(result.message!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w500)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: result.ok ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
            ),
            onPressed: onReset,
            child: Text(result.ok ? l10n.scanNextTicket : l10n.scanTryAgain2),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.inputFill, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: context.textSecondary),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.textMuted, fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary)),
      ]),
    ]),
  );
}
