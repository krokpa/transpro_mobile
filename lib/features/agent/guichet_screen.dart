import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

class GuichetScreen extends ConsumerStatefulWidget {
  const GuichetScreen({super.key});
  @override
  ConsumerState<GuichetScreen> createState() => _State();
}

class _State extends ConsumerState<GuichetScreen> {
  City? _origin;
  City? _dest;
  Trip? _trip;
  int _pax = 1;
  String _method = 'CASH';
  bool _loading = false;
  bool _success = false;
  Map<String, dynamic>? _createdBooking;

  List<City> _cities = [];
  List<Trip> _trips = [];
  bool _loadingCities = false;
  bool _loadingTrips = false;

  static const _methods = [
    ('CASH', 'Espèces', Icons.payments_outlined),
    ('ORANGE_MONEY', 'Orange', Icons.phone_android),
    ('MTN_MOMO', 'MTN', Icons.phone_android),
    ('WAVE', 'Wave', Icons.waves),
  ];

  @override
  void initState() { super.initState(); _loadCities(); }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/cities');
      final items = extractData(res.data);
      setState(() => _cities = (items as List).map((e) => City.fromJson(e)).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadTrips() async {
    if (_origin == null || _dest == null) return;
    setState(() { _loadingTrips = true; _trips = []; _trip = null; });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips', queryParameters: {
        'originCityId': _origin!.id,
        'destinationCityId': _dest!.id,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'status': 'SCHEDULED,BOARDING',
      });
      final items = extractData(res.data);
      setState(() => _trips = (items as List).map((e) => Trip.fromJson(e)).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<void> _sell() async {
    if (_trip == null) return;
    final user = ref.read(authProvider).user!;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/bookings/guichet', data: {
        'tripId': _trip!.id,
        'stationId': user.stationId,
        'passengers': _pax,
        'paymentMethod': _method,
      });
      setState(() { _success = true; _createdBooking = res.data; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${_extractMsg(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractMsg(dynamic e) {
    try { return (e as dynamic).response?.data?['message'] ?? 'Erreur'; } catch (_) { return 'Erreur'; }
  }

  void _reset() => setState(() {
    _trip = null; _pax = 1; _method = 'CASH'; _success = false; _createdBooking = null;
  });

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessView(booking: _createdBooking!, trip: _trip!, pax: _pax, onReset: _reset);
    return Scaffold(
      appBar: AppBar(title: const Text('Vente guichet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // City pickers
          _SectionTitle(title: 'Trajet'),
          Row(children: [
            Expanded(child: _CityDropdown(
              label: 'Départ', value: _origin, cities: _cities,
              onChanged: (c) { setState(() { _origin = c; _trip = null; }); _loadTrips(); },
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: Color(0xFF94A3B8)),
            ),
            Expanded(child: _CityDropdown(
              label: 'Arrivée', value: _dest, cities: _cities,
              onChanged: (c) { setState(() { _dest = c; _trip = null; }); _loadTrips(); },
            )),
          ]),
          const SizedBox(height: 16),

          // Trip selector
          _SectionTitle(title: 'Voyage du jour'),
          if (_loadingTrips) const Center(child: Padding(
            padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (!_loadingTrips && _trips.isNotEmpty) Column(
            children: _trips.map((t) {
              final sel = _trip?.id == t.id;
              return InkWell(
                onTap: () => setState(() => _trip = t),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? brandOrange : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? brandOrange : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(children: [
                    Text(DateFormat('HH:mm').format(t.departureAt.toLocal()),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
                        color: sel ? Colors.white : brandDark)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t.tripClass,
                      style: TextStyle(color: sel ? Colors.white70 : const Color(0xFF64748B), fontSize: 13))),
                    Text('${t.price.toStringAsFixed(0)} F',
                      style: TextStyle(fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : brandOrange)),
                  ]),
                ),
              );
            }).toList(),
          ),
          if (!_loadingTrips && _trips.isEmpty && _origin != null && _dest != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun voyage disponible', style: TextStyle(color: Colors.grey[400])),
            ),

          if (_trip != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Passagers'),
            Row(children: [
              _CountBtn(icon: Icons.remove, onTap: _pax > 1 ? () => setState(() => _pax--) : null),
              const SizedBox(width: 20),
              Text('$_pax', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(width: 20),
              _CountBtn(icon: Icons.add, onTap: _pax < (_trip?.availableSeats ?? 1) ? () => setState(() => _pax++) : null),
              const Spacer(),
              Text('= ${(_trip!.price * _pax).toStringAsFixed(0)} F',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandOrange)),
            ]),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Paiement'),
            Wrap(spacing: 8, runSpacing: 8, children: _methods.map((m) {
              final sel = _method == m.$1;
              return InkWell(
                onTap: () => setState(() => _method = m.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? brandOrange : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? brandOrange : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(m.$3, size: 16, color: sel ? Colors.white : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(m.$2, style: TextStyle(color: sel ? Colors.white : const Color(0xFF64748B),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _sell,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sell_outlined),
              label: Text('Encaisser · ${(_trip!.price * _pax).toStringAsFixed(0)} F'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B))),
  );
}

class _CityDropdown extends StatelessWidget {
  final String label;
  final City? value;
  final List<City> cities;
  final ValueChanged<City?> onChanged;
  const _CityDropdown({required this.label, required this.value, required this.cities, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<City>(
    value: value,
    hint: Text(label, style: const TextStyle(fontSize: 13)),
    decoration: InputDecoration(
      filled: true, fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 13)))).toList(),
    onChanged: onChanged,
  );
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onTap != null ? brandOrange.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: onTap != null ? brandOrange : Colors.grey),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Trip trip;
  final int pax;
  final VoidCallback onReset;
  const _SuccessView({required this.booking, required this.trip, required this.pax, required this.onReset});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 48),
        ),
        const SizedBox(height: 20),
        const Text('Vente réussie !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandDark)),
        const SizedBox(height: 8),
        Text('${trip.originCity} → ${trip.destinationCity}',
          style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        const SizedBox(height: 4),
        Text('$pax passager${pax > 1 ? 's' : ''} · ${DateFormat('HH:mm').format(trip.departureAt.toLocal())}',
          style: TextStyle(color: Colors.grey[400])),
        const SizedBox(height: 16),
        Text('Réf: ${booking['reference'] ?? '—'}',
          style: const TextStyle(fontFamily: 'monospace', color: brandDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: onReset, child: const Text('Nouvelle vente')),
      ]),
    )),
  );
}
