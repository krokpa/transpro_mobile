import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

final _citiesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cities');
  final items = extractData(res.data);
  return (items as List).map((e) => City.fromJson(e)).toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _State();
}

class _State extends ConsumerState<SearchScreen> {
  City? _origin;
  City? _dest;
  DateTime _date = DateTime.now();
  int _passengers = 1;
  List<Trip>? _results;
  bool _loading = false;
  String? _error;

  void _swap() => setState(() { final tmp = _origin; _origin = _dest; _dest = tmp; });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: brandOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _search() async {
    if (_origin == null || _dest == null) {
      setState(() => _error = 'Veuillez sélectionner départ et destination.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips', queryParameters: {
        'originCityId': _origin!.id,
        'destinationCityId': _dest!.id,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'status': 'SCHEDULED,BOARDING',
      });
      final items = extractData(res.data);
      setState(() => _results = (items as List).map((e) => Trip.fromJson(e)).toList());
    } catch (_) {
      setState(() => _error = 'Erreur lors de la recherche.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(_citiesProvider);
    final cities = citiesAsync.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Search form ───────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(children: [
                  // AppBar row
                  Row(children: [
                    const SizedBox(width: 4),
                    const Text('Rechercher',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
                    const Spacer(),
                    if (citiesAsync.isLoading)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange),
                      ),
                  ]),
                  const SizedBox(height: 16),

                  // Origin → Destination row
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Expanded(child: _CityPicker(
                        label: 'Départ',
                        hint: 'D\'où partez-vous ?',
                        city: _origin,
                        cities: cities,
                        icon: Icons.trip_origin_rounded,
                        onChanged: (c) => setState(() => _origin = c),
                      )),
                      GestureDetector(
                        onTap: _swap,
                        child: Container(
                          width: 36, height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: brandOrange, size: 18),
                        ),
                      ),
                      Expanded(child: _CityPicker(
                        label: 'Arrivée',
                        hint: 'Où allez-vous ?',
                        city: _dest,
                        cities: cities,
                        icon: Icons.location_on_rounded,
                        onChanged: (c) => setState(() => _dest = c),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  // Date + passengers row
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEE d MMM', 'fr_FR').format(_date),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: brandDark),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            onPressed: _passengers > 1 ? () => setState(() => _passengers--) : null,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Text('$_passengers', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ]),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            onPressed: _passengers < 9 ? () => setState(() => _passengers++) : null,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ]),
                      ),
                    ),
                  ]),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 6),
                        Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded),
                    label: Text(_loading ? 'Recherche en cours…' : 'Rechercher'),
                  ),
                ]),
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Results ───────────────────────────────────────────────────────
          Expanded(
            child: _results == null
                ? _SearchPrompt()
                : _results!.isEmpty
                    ? _NoResults()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results!.length,
                        itemBuilder: (_, i) => _SearchResultCard(
                          trip: _results![i],
                          passengers: _passengers,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── City picker button ────────────────────────────────────────────────────────

class _CityPicker extends StatelessWidget {
  final String label;
  final String hint;
  final City? city;
  final List<City> cities;
  final IconData icon;
  final ValueChanged<City?> onChanged;
  const _CityPicker({
    required this.label, required this.hint, required this.city,
    required this.cities, required this.icon, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _showPicker(context),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 14, color: city != null ? brandOrange : const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          Text(
            city?.name ?? hint,
            style: TextStyle(
              color: city != null ? brandDark : const Color(0xFF94A3B8),
              fontWeight: city != null ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ])),
      ]),
    ),
  );

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CityPickerSheet(
        title: label,
        cities: cities,
        onSelected: (c) {
          onChanged(c);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  final String title;
  final List<City> cities;
  final ValueChanged<City> onSelected;
  const _CityPickerSheet({required this.title, required this.cities, required this.onSelected});
  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.cities
        .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Rechercher une ville…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: filtered.length,
            itemBuilder: (_, i) => ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: brandLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_city_outlined, color: brandOrange, size: 18),
              ),
              title: Text(filtered[i].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () => widget.onSelected(filtered[i]),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final Trip trip;
  final int passengers;
  const _SearchResultCard({required this.trip, required this.passengers});

  static const _classCfg = {
    'VIP':      (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'EXPRESS':  (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'STANDARD': (Color(0xFFF0FDF4), Color(0xFF16A34A)),
  };

  @override
  Widget build(BuildContext context) {
    final cc = _classCfg[trip.tripClass] ?? _classCfg['STANDARD']!;
    final total = trip.price * passengers;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/passenger/trip/${trip.id}?passengers=$passengers'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${trip.originCity} → ${trip.destinationCity}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  const Icon(Icons.event_seat_outlined, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text('${trip.availableSeats} places',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${trip.price.toStringAsFixed(0)} F',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: brandOrange),
                ),
                if (passengers > 1)
                  Text(
                    'Total: ${total.toStringAsFixed(0)} F',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: cc.$1, borderRadius: BorderRadius.circular(6)),
                  child: Text(trip.tripClass, style: TextStyle(color: cc.$2, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            if (trip.status == 'BOARDING') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.door_front_door_outlined, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text('Embarquement en cours',
                    style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Placeholder states ────────────────────────────────────────────────────────

class _SearchPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: const Icon(Icons.search_rounded, size: 36, color: Color(0xFF94A3B8)),
      ),
      const SizedBox(height: 16),
      const Text('Lancez une recherche', style: TextStyle(fontWeight: FontWeight.w600, color: brandDark)),
      const SizedBox(height: 6),
      const Text('Choisissez vos villes et la date',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
    ]),
  );
}

class _NoResults extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
      ),
      const SizedBox(height: 16),
      const Text('Aucun voyage trouvé', style: TextStyle(fontWeight: FontWeight.w600, color: brandDark)),
      const SizedBox(height: 6),
      const Text('Essayez une autre date ou un autre trajet.',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
    ]),
  );
}
