import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override
  ConsumerState<ScannerScreen> createState() => _State();
}

class _State extends ConsumerState<ScannerScreen> {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _paused = false;
  bool _loading = false;
  _ScanResult? _result;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_paused || _loading) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() { _paused = true; _loading = true; });
    HapticFeedback.mediumImpact();

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/payments/scan', data: {'qrData': code});
      final data = res.data;
      final booking = data['booking'];
      final user = booking?['user'];
      final route = booking?['trip']?['route'];
      setState(() => _result = _ScanResult(
        ok: true,
        passenger: user != null ? '${user['firstName']} ${user['lastName']}' : '—',
        route: route != null ? '${route['originCity']?['name']} → ${route['destinationCity']?['name']}' : '—',
        seat: (booking?['seatNumbers'] as List?)?.join(', ') ?? '—',
      ));
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() => _result = _ScanResult(
        ok: false,
        message: _extractMsg(e),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractMsg(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Billet invalide';
    } catch (_) {}
    return 'Billet invalide ou déjà scanné';
  }

  void _reset() {
    setState(() { _paused = false; _loading = false; _result = null; });
    _ctrl.start();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_paused) MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // Viewfinder overlay
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
              bottom: 140,
              left: 0, right: 0,
              child: Center(child: Text('Centrez le QR code dans le cadre',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14))),
            ),
            SafeArea(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Agent · Scanner', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const Text('Scanner un billet',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            )),
          ],

          // Loading
          if (_loading) Container(
            color: Colors.black.withAlpha(153),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('Vérification…', style: TextStyle(color: Colors.white)),
            ])),
          ),

          // Result
          if (_result != null) SafeArea(child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: _ResultCard(result: _result!, onReset: _reset),
          ))),
        ],
      ),
    );
  }
}

class _ScanResult {
  final bool ok;
  final String? passenger;
  final String? route;
  final String? seat;
  final String? message;
  const _ScanResult({required this.ok, this.passenger, this.route, this.seat, this.message});
}

class _ResultCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onReset;
  const _ResultCard({required this.result, required this.onReset});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(20),
        color: result.ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        child: Row(children: [
          Icon(result.ok ? Icons.check_circle : Icons.cancel,
            color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Text(result.ok ? 'Billet validé ✓' : 'Billet refusé',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: result.ok ? Column(children: [
          _Row(icon: Icons.person, label: 'Passager', value: result.passenger!),
          _Row(icon: Icons.route, label: 'Trajet', value: result.route!),
          _Row(icon: Icons.event_seat_outlined, label: 'Siège(s)', value: result.seat!),
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
          child: Text(result.ok ? 'Scanner le suivant' : 'Réessayer'),
        ),
      ),
    ]),
  );
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
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: brandDark)),
      ]),
    ]),
  );
}
