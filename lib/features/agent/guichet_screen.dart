import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/payment_logo.dart';
import '../../l10n/app_localizations.dart';
import '../passenger/seat_picker.dart';

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
  List<String> _selectedSeats = [];
  String _method = 'CASH';
  bool _loading = false;
  bool _success = false;
  Map<String, dynamic>? _createdBooking;

  List<City> _cities = [];
  List<Trip> _trips = [];
  bool _loadingCities = false;
  bool _loadingTrips = false;

  static const _methods = ['CASH', 'ORANGE_MONEY', 'MTN_MOMO', 'WAVE'];

  String _methodName(String code, AppLocalizations l10n) => switch (code) {
    'CASH'         => l10n.payMethodCash,
    'ORANGE_MONEY' => 'Orange Money',
    'MTN_MOMO'     => 'MTN MoMo',
    'WAVE'         => 'Wave',
    _              => code,
  };

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/cities');
      final items = extractData(res.data);
      setState(
        () => _cities = (items as List).map((e) => City.fromJson(e)).toList(),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadTrips() async {
    if (_origin == null || _dest == null) return;
    setState(() {
      _loadingTrips = true;
      _trips = [];
      _trip = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/trips',
        queryParameters: {
          'originCityId': _origin!.id,
          'destinationCityId': _dest!.id,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'status': 'SCHEDULED,BOARDING',
        },
      );
      final items = extractData(res.data);
      setState(
        () => _trips = (items as List).map((e) => Trip.fromJson(e)).toList(),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<void> _pickSeats() async {
    if (_trip == null) return;
    final seats = await showSeatPicker(
      context: context,
      tripId: _trip!.id,
      maxSeats: _trip!.availableSeats.clamp(1, 10),
      pricePerSeat: _trip!.price,
    );
    if (seats != null) setState(() => _selectedSeats = seats);
  }

  Future<void> _sell() async {
    if (_trip == null) return;
    final user = ref.read(authProvider).user!;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final Map<String, dynamic> payload = {
        'tripId': _trip!.id,
        'stationId': user.stationId,
        'paymentMethod': _method,
      };
      if (_trip!.advancedSeatManagement) {
        payload['seatNumbers'] = _selectedSeats;
      } else {
        payload['passengerCount'] = _pax;
        payload['seatNumbers'] = <String>[];
      }
      final res = await dio.post('/bookings/guichet', data: payload);
      setState(() {
        _success = true;
        _createdBooking = extractData(res.data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() => setState(() {
    _trip = null;
    _pax = 1;
    _selectedSeats = [];
    _method = 'CASH';
    _success = false;
    _createdBooking = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectivePax = (_trip?.advancedSeatManagement ?? true)
        ? _selectedSeats.length
        : _pax;
    if (_success)
      return _SuccessView(
        booking: _createdBooking!,
        trip: _trip!,
        pax: effectivePax,
        onReset: _reset,
      );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guichetTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: l10n.guichetSectionRoute),
            if (_loadingCities)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Row(
              children: [
                Expanded(
                  child: _CityDropdown(
                    label: l10n.guichetDeparture,
                    value: _origin,
                    cities: _cities,
                    onChanged: (c) {
                      setState(() {
                        _origin = c;
                        _trip = null;
                      });
                      _loadTrips();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: context.textMuted),
                ),
                Expanded(
                  child: _CityDropdown(
                    label: l10n.guichetArrival,
                    value: _dest,
                    cities: _cities,
                    onChanged: (c) {
                      setState(() {
                        _dest = c;
                        _trip = null;
                      });
                      _loadTrips();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _SectionTitle(title: l10n.guichetSectionDayTrips),
            if (_loadingTrips)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loadingTrips && _trips.isNotEmpty)
              Column(
                children: _trips.map((t) {
                  final sel = _trip?.id == t.id;
                  return InkWell(
                    onTap: () => setState(() {
                      _trip = t;
                      _selectedSeats = [];
                      _pax = 1;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: sel ? brandOrange : context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? brandOrange : context.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('HH:mm').format(t.departureAt.toLocal()),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: sel ? Colors.white : context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.tripClass,
                              style: TextStyle(
                                color: sel
                                    ? Colors.white70
                                    : context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${t.price.toStringAsFixed(0)} F',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : brandOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (!_loadingTrips &&
                _trips.isEmpty &&
                _origin != null &&
                _dest != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.guichetNoTripsAvailable,
                  style: TextStyle(color: context.textMuted),
                ),
              ),

            if (_trip != null) ...[
              const SizedBox(height: 16),
              if (_trip!.advancedSeatManagement) ...[
                _SectionTitle(title: l10n.guichetSectionSeats),
                if (_selectedSeats.isEmpty)
                  InkWell(
                    onTap: _pickSeats,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.tagBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandOrange.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event_seat_outlined,
                            color: brandOrange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.guichetChooseSeats,
                            style: const TextStyle(
                              color: brandOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._selectedSeats.map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: brandOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.event_seat,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    s,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pickSeats,
                            icon: const Icon(Icons.edit, size: 14),
                            label: Text(
                              l10n.guichetModify,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '= ${(_trip!.price * _selectedSeats.length).toStringAsFixed(0)} F',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: brandOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ] else ...[
                _SectionTitle(title: l10n.guichetSectionPax),
                Row(
                  children: [
                    _CountBtn(
                      icon: Icons.remove,
                      onTap: _pax > 1 ? () => setState(() => _pax--) : null,
                    ),
                    const SizedBox(width: 20),
                    Text(
                      '$_pax',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _CountBtn(
                      icon: Icons.add,
                      onTap: _pax < (_trip?.availableSeats ?? 1)
                          ? () => setState(() => _pax++)
                          : null,
                    ),
                    const Spacer(),
                    Text(
                      '= ${(_trip!.price * _pax).toStringAsFixed(0)} F',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: brandOrange,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _SectionTitle(title: l10n.guichetPaymentSection),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _methods.map((m) {
                  final sel = _method == m;
                  return InkWell(
                    onTap: () => setState(() => _method = m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? brandOrange.withValues(alpha: 0.08) : context.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? brandOrange : context.divider,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PaymentLogo(method: m, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _methodName(m, l10n),
                          style: TextStyle(
                            color: sel ? brandOrange : context.textSecondary,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final useASM = _trip!.advancedSeatManagement;
                  final canSell = useASM ? _selectedSeats.isNotEmpty : true;
                  final total = useASM
                      ? _trip!.price * _selectedSeats.length
                      : _trip!.price * _pax;
                  return ElevatedButton.icon(
                    onPressed: (_loading || !canSell) ? null : _sell,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sell_outlined),
                    label: Text(
                      canSell
                          ? l10n.guichetCollectBtn(total.toStringAsFixed(0))
                          : l10n.guichetSelectSeatsFirst,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
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
    child: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: context.textSecondary,
      ),
    ),
  );
}

class _CityDropdown extends StatelessWidget {
  final String label;
  final City? value;
  final List<City> cities;
  final ValueChanged<City?> onChanged;
  const _CityDropdown({
    required this.label,
    required this.value,
    required this.cities,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<City>(
    initialValue: value,
    hint: Text(label, style: const TextStyle(fontSize: 13)),
    decoration: InputDecoration(
      filled: true,
      fillColor: context.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    items: cities
        .map(
          (c) => DropdownMenuItem(
            value: c,
            child: Text(c.name, style: const TextStyle(fontSize: 13)),
          ),
        )
        .toList(),
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onTap != null
            ? brandOrange.withValues(alpha: 0.1)
            : context.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap != null ? brandOrange : context.textMuted,
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Trip trip;
  final int pax;
  final VoidCallback onReset;
  const _SuccessView({
    required this.booking,
    required this.trip,
    required this.pax,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16A34A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.guichetSaleSuccess,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${trip.originCity} → ${trip.destinationCity}',
                style: TextStyle(color: context.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '$pax ${l10n.departurePaxSuffix} · ${DateFormat('HH:mm').format(trip.departureAt.toLocal())}',
                style: TextStyle(color: context.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                '${l10n.bookingRef}: ${booking['reference'] ?? '—'}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onReset,
                child: Text(l10n.guichetNewSale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
