import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/payment_logo.dart';
import '../../core/widgets/phone_input_field.dart';
import '../../l10n/app_localizations.dart';
import '../../core/connectivity/require_online.dart';
import '../passenger/seat_picker.dart';
import 'ticket_actions.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class GuichetScreen extends ConsumerStatefulWidget {
  const GuichetScreen({super.key});
  @override
  ConsumerState<GuichetScreen> createState() => _GuichetState();
}

class _GuichetState extends ConsumerState<GuichetScreen> {
  City?        _origin;
  City?        _dest;
  Trip?        _trip;
  int          _pax          = 1;
  List<String> _selectedSeats = [];
  String       _method       = 'CASH';
  bool         _loading      = false;
  bool         _success      = false;
  Map<String, dynamic>? _createdBooking;

  List<City> _cities       = [];
  List<Trip> _trips        = [];
  bool       _loadingCities = false;
  bool       _loadingTrips  = false;

  final _scrollCtrl   = ScrollController();
  final _passengerKey = GlobalKey();

  // Lookup passager par téléphone
  final _phoneCtrl              = TextEditingController();
  bool                   _lookingUp         = false;
  bool                   _hasLookedUp       = false;
  Map<String, dynamic>?  _lookedUpPassenger;
  Timer?                 _debounceTimer;

  static const _methods = [
    ('CASH',         'Espèces',      Color(0xFF16A34A)),
    ('ORANGE_MONEY', 'Orange Money', Color(0xFFEA580C)),
    ('MTN_MOMO',     'MTN MoMo',    Color(0xFFCA8A04)),
    ('WAVE',         'Wave',         Color(0xFF0284C7)),
  ];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _phoneCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final res = await ref.read(dioProvider).get('/cities');
      final items = extractData(res.data);
      setState(() => _cities = (items as List).map((e) => City.fromJson(e)).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _loadTrips() async {
    if (_origin == null || _dest == null) return;
    setState(() { _loadingTrips = true; _trips = []; _trip = null; });
    try {
      final res = await ref.read(dioProvider).get('/trips', queryParameters: {
        'originCityId':      _origin!.id,
        'destinationCityId': _dest!.id,
        'date':              DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'status':            'SCHEDULED,BOARDING',
      });
      final items = extractData(res.data);
      setState(() => _trips = (items as List).map((e) => Trip.fromJson(e)).toList());
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

  Future<void> _showCityPicker(bool isOrigin) async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        cities: _cities,
        title: isOrigin ? 'Ville de départ' : "Ville d'arrivée",
        exclude: isOrigin ? _dest : _origin,
      ),
    );
    if (city == null || !mounted) return;
    setState(() {
      if (isOrigin) { _origin = city; } else { _dest = city; }
      _trip = null;
      _selectedSeats = [];
    });
    _loadTrips();
  }

  Future<void> _sell() async {
    if (_trip == null) return;
    if (!requireOnline(context, ref)) return;
    final user = ref.read(authProvider).user!;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final useASM = _trip!.advancedSeatManagement;
      final payload = <String, dynamic>{
        'tripId':        _trip!.id,
        'stationId':     user.stationId,
        'paymentMethod': _method,
      };
      if (useASM) {
        payload['seatNumbers'] = _selectedSeats;
      } else {
        payload['passengerCount'] = _pax;
        payload['seatNumbers']   = <String>[];
      }
      final phone = _phoneCtrl.text.trim();
      if (phone.isNotEmpty) payload['phone'] = phone;
      final res = await ref.read(dioProvider).post('/bookings/guichet', data: payload);
      HapticFeedback.heavyImpact();
      setState(() { _success = true; _createdBooking = extractData(res.data); });
    } catch (e) {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _phoneCtrl.clear();
    _debounceTimer?.cancel();
    setState(() {
      _trip = null; _pax = 1; _selectedSeats = [];
      _method = 'CASH'; _success = false; _createdBooking = null;
      _lookingUp = false; _hasLookedUp = false; _lookedUpPassenger = null;
    });
  }

  void _selectTrip(Trip t) {
    setState(() { _trip = t; _selectedSeats = []; _pax = 1; });
    // Attend la fin de l'animation AnimatedSize (250ms) puis scroll jusqu'à
    // la section passagers/sièges (bas du contenu)
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Lookup passager ──────────────────────────────────────────────────────────

  void _onPhoneChanged(String val) {
    _debounceTimer?.cancel();
    final phone = val.trim();
    if (phone.length < 8) {
      setState(() {
        _lookingUp = false;
        _hasLookedUp = false;
        _lookedUpPassenger = null;
      });
      return;
    }
    setState(() {
      _lookingUp = true;
      _hasLookedUp = false;
      _lookedUpPassenger = null;
    });
    _debounceTimer = Timer(
      const Duration(milliseconds: 600),
      () => _doLookup(phone),
    );
  }

  Future<void> _doLookup(String phone) async {
    try {
      final res = await ref
          .read(dioProvider)
          .get('/users/lookup', queryParameters: {'phone': phone});
      final data = res.data['data'];
      if (!mounted) return;
      setState(() {
        _lookedUpPassenger = data is Map<String, dynamic> ? data : null;
        _hasLookedUp = true;
        _lookingUp = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _hasLookedUp = true;
        _lookedUpPassenger = null;
      });
    }
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  int    get _effectivePax   => _trip?.advancedSeatManagement == true ? _selectedSeats.length : _pax;
  double get _effectiveTotal => (_trip?.price ?? 0) * _effectivePax;
  bool   get _canSell        => _trip != null && (_trip!.advancedSeatManagement ? _selectedSeats.isNotEmpty : true);

  String _methodLabel(String code) => switch (code) {
    'CASH'         => 'Espèces',
    'ORANGE_MONEY' => 'Orange Money',
    'MTN_MOMO'     => 'MTN MoMo',
    'WAVE'         => 'Wave',
    _              => code,
  };

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_success) {
      return _SuccessView(
        booking:     _createdBooking!,
        trip:        _trip!,
        pax:         _effectivePax,
        seatNumbers: _selectedSeats,
        methodLabel: _methodLabel(_method),
        bookingId:   (_createdBooking!['id'] as String?) ?? '',
        tripId:      _trip!.id,
        onReset:     _reset,
      );
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.guichetTitle),
          Text(
            ref.read(authProvider).user?.stationName ?? '',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: context.textMuted),
          ),
        ]),
      ),

      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── TRAJET ─────────────────────────────────────────────────
                _SectionHeader(icon: Icons.route_outlined, label: 'TRAJET'),
                const SizedBox(height: 10),
                if (_loadingCities)
                  const LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.all(Radius.circular(1))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _DestCard(
                      icon: Icons.trip_origin,
                      label: 'Départ',
                      value: _origin,
                      onTap: _loadingCities ? null : () => _showCityPicker(true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.divider),
                      ),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: context.textMuted),
                    ),
                  ),
                  Expanded(
                    child: _DestCard(
                      icon: Icons.location_on_outlined,
                      label: 'Arrivée',
                      value: _dest,
                      onTap: _loadingCities ? null : () => _showCityPicker(false),
                    ),
                  ),
                ]),

                // ── VOYAGES ─────────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: (_origin == null || _dest == null)
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _SectionHeader(
                              icon: Icons.departure_board_outlined,
                              label: 'VOYAGES DU JOUR',
                              trailing: _loadingTrips
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            if (!_loadingTrips && _trips.isEmpty)
                              _EmptyTrips(
                                origin: _origin!.name,
                                dest:   _dest!.name,
                              )
                            else
                              ...(_trips.map((t) => _TripCard(
                                trip:     t,
                                selected: _trip?.id == t.id,
                                onTap: t.availableSeats == 0 ? null : () => _selectTrip(t),
                              ))),
                          ],
                        ),
                ),

                // ── PASSAGERS / SIÈGES ──────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _trip == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(key: _passengerKey, height: 24),
                            if (_trip!.advancedSeatManagement) ...[
                              _SectionHeader(
                                icon: Icons.event_seat_outlined,
                                label: 'SIÈGES',
                              ),
                              const SizedBox(height: 10),
                              _SeatPickerCard(
                                trip:          _trip!,
                                selectedSeats: _selectedSeats,
                                onPick:        _pickSeats,
                              ),
                            ] else ...[
                              _SectionHeader(
                                icon: Icons.people_outline,
                                label: 'PASSAGERS',
                              ),
                              const SizedBox(height: 10),
                              _PaxCounter(
                                pax:     _pax,
                                max:     _trip!.availableSeats,
                                price:   _trip!.price,
                                onMinus: _pax > 1 ? () => setState(() => _pax--) : null,
                                onPlus:  _pax < _trip!.availableSeats ? () => setState(() => _pax++) : null,
                                onQuick: (n) => setState(() => _pax = n),
                              ),
                            ],

                            // ── PAIEMENT ─────────────────────────────────────
                            const SizedBox(height: 24),
                            _SectionHeader(
                              icon: Icons.payments_outlined,
                              label: 'MODE DE PAIEMENT',
                            ),
                            const SizedBox(height: 10),
                            _PaymentGrid(
                              methods:  _methods,
                              selected: _method,
                              onSelect: (m) => setState(() => _method = m),
                            ),

                            // ── TÉLÉPHONE PASSAGER ────────────────────────────
                            const SizedBox(height: 24),
                            _SectionHeader(
                              icon: Icons.person_search_outlined,
                              label: 'PASSAGER (optionnel)',
                            ),
                            const SizedBox(height: 10),
                            PhoneInputField(
                              controller: _phoneCtrl,
                              onChanged:  _onPhoneChanged,
                              suffixIcon: _lookingUp
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            _PassengerLookupBadge(
                              lookingUp:  _lookingUp,
                              hasLookedUp: _hasLookedUp,
                              passenger:  _lookedUpPassenger,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),

        // ── Barre d'encaissement (inline dans le body, pas bottomNavigationBar) ──
        if (_trip != null) _CheckoutBar(
          pax:         _effectivePax,
          total:       _effectiveTotal,
          canSell:     _canSell,
          loading:     _loading,
          onSell:      _sell,
          onPickSeats: _trip!.advancedSeatManagement ? _pickSeats : null,
        ),
      ]),
    );
  }
}

// ── City picker bottom sheet ─────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final List<City> cities;
  final String     title;
  final City?      exclude;
  const _CityPickerSheet({required this.cities, required this.title, this.exclude});
  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _ctrl = TextEditingController();
  String _q   = '';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.cities
        .where((c) => c.id != widget.exclude?.id)
        .where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: context.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: context.textMuted),
              style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
            ),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Rechercher une ville...',
              prefixIcon: Icon(Icons.search, size: 20, color: context.textMuted),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () { _ctrl.clear(); setState(() => _q = ''); },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('Aucune ville trouvée',
                        style: TextStyle(color: context.textMuted)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1, indent: 56, color: context.divider),
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      leading: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: brandOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_city_outlined,
                            color: brandOrange, size: 18),
                      ),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── City destination card ─────────────────────────────────────────────────────

class _DestCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final City?    value;
  final VoidCallback? onTap;
  const _DestCard({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value != null
            ? brandOrange.withValues(alpha: 0.06)
            : context.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null ? brandOrange.withValues(alpha: 0.5) : context.divider,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13,
              color: value != null ? brandOrange : context.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: value != null ? brandOrange : context.textMuted,
                letterSpacing: 0.3,
              )),
        ]),
        const SizedBox(height: 5),
        value != null
            ? Text(value!.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              )
            : Text('Choisir',
                style: TextStyle(fontSize: 14, color: context.textMuted)),
        const SizedBox(height: 2),
        Icon(Icons.keyboard_arrow_down, size: 14, color: context.textMuted),
      ]),
    ),
  );
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Trip     trip;
  final bool     selected;
  final VoidCallback? onTap;
  const _TripCard({required this.trip, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final full   = trip.availableSeats == 0;
    final pct    = trip.totalSeats > 0
        ? (trip.totalSeats - trip.availableSeats) / trip.totalSeats
        : 0.0;
    final locale = Localizations.localeOf(context).toString();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: full
              ? context.inputFill
              : selected ? brandCanvas : context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: full
                ? context.divider
                : selected ? brandOrange : context.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: brandOrange.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Heure
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                DateFormat('HH:mm').format(trip.departureAt.toLocal()),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: full
                      ? context.textMuted
                      : selected ? Colors.white : brandOrange,
                ),
              ),
              Text(
                trip.tripClass,
                style: TextStyle(
                  fontSize: 11,
                  color: full
                      ? context.textMuted
                      : selected ? Colors.white54 : context.textMuted,
                ),
              ),
            ]),
            const SizedBox(width: 16),
            // Info + barre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trip.vehiclePlate != null)
                    Text(
                      trip.vehiclePlate!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: full
                            ? context.textMuted
                            : selected ? Colors.white54 : context.textMuted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: selected
                          ? Colors.white.withValues(alpha: 0.2)
                          : context.divider,
                      valueColor: AlwaysStoppedAnimation(
                        full ? Colors.red
                            : selected ? Colors.white
                            : pct > 0.8 ? Colors.red : brandOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    full
                        ? 'Complet'
                        : '${trip.availableSeats} place${trip.availableSeats > 1 ? 's' : ''} disponible${trip.availableSeats > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: full ? FontWeight.w700 : FontWeight.normal,
                      color: full
                          ? Colors.red
                          : selected ? Colors.white70 : context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Prix + sélection
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${NumberFormat('#,###', locale).format(trip.price.toInt())} F',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: full
                      ? context.textMuted
                      : selected ? Colors.white : brandOrange,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? brandOrange : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? brandOrange
                        : context.divider,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Empty trips placeholder ───────────────────────────────────────────────────

class _EmptyTrips extends StatelessWidget {
  final String origin;
  final String dest;
  const _EmptyTrips({required this.origin, required this.dest});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: context.inputFill,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      Icon(Icons.departure_board_outlined, size: 36, color: Colors.grey[300]),
      const SizedBox(height: 10),
      Text(
        'Aucun voyage $origin → $dest aujourd\'hui',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textMuted, fontSize: 13),
      ),
    ]),
  );
}

// ── Seat picker card ──────────────────────────────────────────────────────────

class _SeatPickerCard extends StatelessWidget {
  final Trip         trip;
  final List<String> selectedSeats;
  final VoidCallback onPick;
  const _SeatPickerCard({required this.trip, required this.selectedSeats, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    if (selectedSeats.isEmpty) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brandOrange.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_seat_outlined, color: brandOrange),
              SizedBox(width: 10),
              Text('Choisir les sièges',
                  style: TextStyle(
                    color: brandOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_seat_outlined, size: 16, color: brandOrange),
          const SizedBox(width: 6),
          Text('${selectedSeats.length} siège${selectedSeats.length > 1 ? 's' : ''} sélectionné${selectedSeats.length > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          Text(
            '${NumberFormat('#,###', locale).format((trip.price * selectedSeats.length).toInt())} F',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: brandOrange,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: selectedSeats.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: brandOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_seat, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(s, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          )).toList(),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: const Text('Modifier les sièges', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: context.textSecondary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 28),
          ),
        ),
      ]),
    );
  }
}

// ── Passenger counter ────────────────────────────────────────────────────────

class _PaxCounter extends StatelessWidget {
  final int          pax;
  final int          max;
  final double       price;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final ValueChanged<int> onQuick;
  const _PaxCounter({
    required this.pax, required this.max, required this.price,
    this.onMinus, this.onPlus, required this.onQuick,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final total  = (price * pax).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider),
      ),
      child: Column(children: [
        // ── Compteur ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterBtn(icon: Icons.remove_rounded, onTap: onMinus),
            const SizedBox(width: 24),
            Column(children: [
              Text(
                '$pax',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  height: 1,
                ),
              ),
              Text(
                'passager${pax > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ]),
            const SizedBox(width: 24),
            _CounterBtn(icon: Icons.add_rounded, onTap: onPlus),
          ],
        ),
        const SizedBox(height: 12),
        // ── Total (pleine largeur) ───────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(
              '${NumberFormat('#,###', locale).format(total)} F',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: brandOrange,
              ),
            ),
            Text(
              '${NumberFormat('#,###', locale).format(price.toInt())} F × $pax',
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // ── Raccourcis ──────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [1, 2, 3, 4, 5].map((n) {
            if (n > max) return const SizedBox.shrink();
            final sel = pax == n;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onQuick(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? brandOrange : context.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? brandOrange : context.divider,
                    ),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: sel ? Colors.white : context.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CounterBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: onTap != null
            ? brandOrange.withValues(alpha: 0.12)
            : context.inputFill,
        shape: BoxShape.circle,
        border: Border.all(
          color: onTap != null ? brandOrange.withValues(alpha: 0.4) : context.divider,
        ),
      ),
      child: Icon(icon, size: 24,
          color: onTap != null ? brandOrange : context.textMuted),
    ),
  );
}

// ── Payment grid ──────────────────────────────────────────────────────────────

class _PaymentGrid extends StatelessWidget {
  final List<(String, String, Color)> methods;
  final String selected;
  final ValueChanged<String> onSelect;
  const _PaymentGrid({required this.methods, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.8,
    children: methods.map((m) {
      final sel = selected == m.$1;
      return GestureDetector(
        onTap: () => onSelect(m.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? m.$3.withValues(alpha: 0.10) : context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? m.$3 : context.divider,
              width: sel ? 2 : 1,
            ),
          ),
          child: Row(children: [
            PaymentLogo(method: m.$1, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? m.$3 : context.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sel)
              Icon(Icons.check_circle_rounded, size: 16, color: m.$3),
          ]),
        ),
      );
    }).toList(),
  );
}

// ── Passenger lookup badge ────────────────────────────────────────────────────

class _PassengerLookupBadge extends StatelessWidget {
  final bool lookingUp;
  final bool hasLookedUp;
  final Map<String, dynamic>? passenger;
  const _PassengerLookupBadge({
    required this.lookingUp,
    required this.hasLookedUp,
    required this.passenger,
  });

  @override
  Widget build(BuildContext context) {
    if (lookingUp) {
      return Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Vérification en cours...',
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
      ]);
    }

    if (!hasLookedUp) return const SizedBox.shrink();

    if (passenger != null) {
      // Passager inscrit trouvé
      final firstName = passenger!['firstName'] as String? ?? '';
      final lastName  = passenger!['lastName']  as String? ?? '';
      final initials  = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName $lastName'.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF15803D),
                  ),
                ),
                const Text(
                  'Passager inscrit — vente attribuée',
                  style: TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF16A34A), size: 18),
        ]),
      );
    }

    // Numéro non trouvé → nouveau client
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Row(children: [
        Icon(Icons.person_add_outlined, size: 18, color: context.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Numéro non inscrit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.textPrimary,
                ),
              ),
              Text(
                'Un compte client sera créé automatiquement',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Sticky checkout bar ──────────────────────────────────────────────────────

class _CheckoutBar extends StatelessWidget {
  final int    pax;
  final double total;
  final bool   canSell;
  final bool   loading;
  final VoidCallback  onSell;
  final VoidCallback? onPickSeats;
  const _CheckoutBar({
    required this.pax, required this.total,
    required this.canSell, required this.loading, required this.onSell,
    this.onPickSeats,
  });

  @override
  Widget build(BuildContext context) {
    final locale     = Localizations.localeOf(context).toString();
    // Mode "sélection de sièges" : pas encore de sièges mais trip ASM sélectionné
    final isPickMode = !canSell && onPickSeats != null;
    final isActive   = canSell || isPickMode;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isPickMode ? 'Sièges non choisis' : '$pax passager${pax > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
          Text(
            isPickMode
                ? '— F'
                : '${NumberFormat('#,###', locale).format(total.toInt())} F',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isPickMode ? context.textMuted : context.textPrimary,
            ),
          ),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: loading
                  ? null
                  : isPickMode
                      ? onPickSeats
                      : canSell ? onSell : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? brandOrange : context.inputFill,
                foregroundColor: isActive ? Colors.white : context.textMuted,
                elevation: isActive ? 2 : 0,
                shadowColor: brandOrange.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPickMode
                              ? Icons.event_seat_outlined
                              : Icons.sell_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(isPickMode ? 'Choisir les sièges' : 'Encaisser'),
                      ],
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget?  trailing;
  const _SectionHeader({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: context.textMuted),
    const SizedBox(width: 6),
    Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.textMuted,
        letterSpacing: 0.8,
      ),
    ),
    if (trailing != null) ...[const SizedBox(width: 8), trailing!],
  ]);
}

// ── Success / receipt view ────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Trip         trip;
  final int          pax;
  final List<String> seatNumbers;
  final String       methodLabel;
  final String       bookingId;
  final String       tripId;
  final VoidCallback onReset;
  const _SuccessView({
    required this.booking, required this.trip, required this.pax,
    required this.seatNumbers, required this.methodLabel,
    required this.bookingId, required this.tripId, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final total  = (trip.price * pax).toInt();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 16),
            // Icône succès
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF16A34A), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Vente confirmée !',
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: context.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${trip.originCity} → ${trip.destinationCity}',
              style: TextStyle(color: context.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 32),

            // ── Reçu ─────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [
                // En-tête reçu
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandOrange.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          trip.originCity,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: context.textPrimary,
                          ),
                        ),
                        Row(children: [
                          const Icon(Icons.arrow_forward,
                              size: 12, color: brandOrange),
                          const SizedBox(width: 4),
                          Text(trip.destinationCity,
                              style: const TextStyle(
                                  color: brandOrange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ]),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        DateFormat('HH:mm')
                            .format(trip.departureAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: brandOrange,
                        ),
                      ),
                      Text(
                        DateFormat('EEE d MMM', locale)
                            .format(trip.departureAt.toLocal()),
                        style: TextStyle(
                            fontSize: 11, color: context.textMuted),
                      ),
                    ]),
                  ]),
                ),

                // Séparateur avec encoches
                _TicketDivider(),

                // Détails
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    _ReceiptRow(
                      label: 'Référence',
                      value: booking['reference'] ?? '—',
                      mono: true,
                    ),
                    const SizedBox(height: 10),
                    _ReceiptRow(label: 'Passagers', value: '$pax'),
                    if (seatNumbers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ReceiptRow(
                          label: 'Sièges', value: seatNumbers.join(', ')),
                    ],
                    const SizedBox(height: 10),
                    _ReceiptRow(label: 'Classe', value: trip.tripClass),
                    const SizedBox(height: 10),
                    _ReceiptRow(label: 'Paiement', value: methodLabel),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    Row(children: [
                      Text('TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: context.textPrimary,
                          )),
                      const Spacer(),
                      Text(
                        '${NumberFormat('#,###', locale).format(total)} F',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: brandOrange,
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 24),
            // Remise du billet au client : QR à l'écran ou envoi SMS.
            TicketActions(booking: booking),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle vente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _LuggageDeclarationSheet(
                    bookingId: bookingId,
                  ),
                ),
                icon: const Icon(Icons.luggage_outlined, size: 18),
                label: const Text('Déclarer les bagages (optionnel)'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                  foregroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/agent'),
              child: Text('Retour aux départs',
                  style: TextStyle(color: context.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Luggage declaration sheet ─────────────────────────────────────────────────

class _LuggageDeclarationSheet extends ConsumerStatefulWidget {
  final String bookingId;
  const _LuggageDeclarationSheet({required this.bookingId});

  @override
  ConsumerState<_LuggageDeclarationSheet> createState() => _LuggageDeclarationSheetState();
}

class _LuggageDeclarationSheetState extends ConsumerState<_LuggageDeclarationSheet> {
  int    _bagCount = 1;
  final  _weightCtrl = TextEditingController();
  bool   _loading  = false;
  bool   _done     = false;

  static const _freeKg   = 20.0;
  static const _rateXof  = 300;

  double get _weight  => double.tryParse(_weightCtrl.text) ?? 0;
  double get _excess  => (_weight - _freeKg).clamp(0, double.infinity);
  int    get _fee     => (_excess * _rateXof).round();

  @override
  void dispose() { _weightCtrl.dispose(); super.dispose(); }

  Future<void> _declare() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/luggage/declare', data: {
        'bookingId':    widget.bookingId,
        'bagCount':     _bagCount,
        if (_weight > 0) 'totalWeightKg': _weight,
        'freeWeightKg': _freeKg,
      });
      if (mounted) setState(() { _done = true; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, pad + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        Row(children: [
          const Icon(Icons.luggage_outlined, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 8),
          Text('Déclarer les bagages',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Ignorer', style: TextStyle(color: context.textMuted, fontSize: 13))),
        ]),
        const SizedBox(height: 16),

        if (_done) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '$_bagCount sac${_bagCount > 1 ? "s" : ""} déclaré${_bagCount > 1 ? "s" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534)),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: brandOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Fermer'),
            )),
        ] else ...[
          // Bag count stepper
          Row(children: [
            Text('Nombre de sacs', style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _bagCount > 0 ? () => setState(() => _bagCount--) : null,
              color: const Color(0xFF7C3AED),
            ),
            Text('$_bagCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _bagCount < 20 ? () => setState(() => _bagCount++) : null,
              color: const Color(0xFF7C3AED),
            ),
          ]),
          const SizedBox(height: 12),

          // Weight
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Poids total (kg) — franchise $_freeKg kg',
              suffixText: 'kg',
            ),
          ),

          // Excess fee
          if (_excess > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Excédent : ${_excess.toStringAsFixed(1)} kg × $_rateXof F = $_fee F CFA',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading || _bagCount == 0 ? null : _declare,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.luggage_outlined, size: 18),
              label: Text(_loading ? 'Déclaration…' : 'Déclarer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Ticket divider avec encoches ─────────────────────────────────────────────

class _TicketDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Transform.translate(
      offset: const Offset(-1, 0),
      child: Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          shape: BoxShape.circle,
          border: Border.all(color: context.divider),
        ),
      ),
    ),
    Expanded(
      child: LayoutBuilder(builder: (_, c) {
        final count = (c.maxWidth / 8).floor();
        return Row(
          children: List.generate(count, (_) => const _Dash()),
        );
      }),
    ),
    Transform.translate(
      offset: const Offset(1, 0),
      child: Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          shape: BoxShape.circle,
          border: Border.all(color: context.divider),
        ),
      ),
    ),
  ]);
}

class _Dash extends StatelessWidget {
  const _Dash();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Container(
      width: 4, height: 1,
      color: context.divider,
    ),
  );
}

// ── Receipt row ───────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   mono;
  const _ReceiptRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontSize: 13, color: context.textMuted)),
    const Spacer(),
    Text(
      value,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.textPrimary,
        fontFamily: mono ? 'monospace' : null,
      ),
    ),
  ]);
}
