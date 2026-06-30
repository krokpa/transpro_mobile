import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/fade_slide.dart';
import '../../l10n/app_localizations.dart';

final _citiesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cities');
  final items = extractData(res.data);
  return (items as List).map((e) => City.fromJson(e)).toList();
});

final _tenantsProvider = FutureProvider.autoDispose<List<Tenant>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/tenants/public');
  final items = extractData(res.data);
  return (items as List).map((e) => Tenant.fromJson(e)).toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  /// Optional prefill — passed from the Home hero so a search can be launched
  /// in 2 taps. When [originName] and [destName] are both set, the search runs
  /// automatically as soon as the cities list is available.
  final String? originName;
  final String? destName;
  final String? dateIso;
  final int? passengers;
  final String? companySlug;

  const SearchScreen({
    super.key,
    this.originName,
    this.destName,
    this.dateIso,
    this.passengers,
    this.companySlug,
  });
  @override
  ConsumerState<SearchScreen> createState() => _State();
}

class _State extends ConsumerState<SearchScreen> {
  City? _origin;
  City? _dest;
  DateTime _date = DateTime.now();
  int _passengers = 1;
  Tenant? _company;
  List<Trip>? _results;
  bool _loading = false;
  String? _error;

  /// Guards the one-shot prefill so it doesn't re-apply on every rebuild.
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    if (widget.passengers != null && widget.passengers! > 0) {
      _passengers = widget.passengers!.clamp(1, 9);
    }
    final d = widget.dateIso != null ? DateTime.tryParse(widget.dateIso!) : null;
    if (d != null) _date = d;
  }

  /// Matches the prefill city/company names against the loaded lists and, when
  /// both endpoints resolve, launches the search automatically. If a company
  /// was requested, waits for the tenants list before applying.
  void _applyPrefill(List<City> cities, List<Tenant> tenants) {
    if (_prefillApplied || cities.isEmpty) return;
    final hasCityPrefill =
        widget.originName != null || widget.destName != null;
    final hasCompanyPrefill = widget.companySlug != null;
    if (!hasCityPrefill && !hasCompanyPrefill) return;
    // Wait for tenants before applying when a company preference was passed.
    if (hasCompanyPrefill && tenants.isEmpty) return;
    _prefillApplied = true;

    City? matchCity(String? name) {
      if (name == null) return null;
      final lower = name.toLowerCase();
      for (final c in cities) {
        if (c.name.toLowerCase() == lower) return c;
      }
      return null;
    }

    _origin = matchCity(widget.originName) ?? _origin;
    _dest = matchCity(widget.destName) ?? _dest;
    if (hasCompanyPrefill) {
      for (final t in tenants) {
        if (t.slug == widget.companySlug) {
          _company = t;
          break;
        }
      }
    }

    if (_origin != null && _dest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  void _swap() => setState(() {
    final tmp = _origin;
    _origin = _dest;
    _dest = tmp;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: brandOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    if (_origin == null || _dest == null) {
      setState(() => _error = l10n.searchMissingFields);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final params = <String, dynamic>{
        'origin': _origin!.name,
        'destination': _dest!.name,
        'departureDate': DateFormat('yyyy-MM-dd').format(_date),
        'passengers': _passengers,
      };
      if (_company != null) params['tenantSlug'] = _company!.slug;
      final res = await dio.get('/trips/search', queryParameters: params);
      final items = extractData(res.data);
      setState(
        () => _results = (items as List).map((e) => Trip.fromJson(e)).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Search] error: $e');
      setState(() => _error = l10n.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final citiesAsync = ref.watch(_citiesProvider);
    final tenantsAsync = ref.watch(_tenantsProvider);
    final cities = citiesAsync.value ?? [];
    final tenants = tenantsAsync.value ?? [];

    // One-shot prefill coming from the Home hero (origin/dest/date/passengers/company).
    if (cities.isNotEmpty) _applyPrefill(cities, tenants);

    return Scaffold(
      body: Column(
        children: [
          // ── Search form ─────────────────────────────────────────────────────
          Container(
            color: context.cardBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // Title row
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Text(
                          l10n.search,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (citiesAsync.isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: brandOrange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Origin → Destination row
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CityPicker(
                              label: l10n.searchFromCity,
                              hint: l10n.searchOriginHint,
                              city: _origin,
                              cities: cities,
                              icon: Icons.trip_origin_rounded,
                              onChanged: (c) => setState(() => _origin = c),
                            ),
                          ),
                          GestureDetector(
                            onTap: _swap,
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                color: brandOrange,
                                size: 18,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _CityPicker(
                              label: l10n.searchToCity,
                              hint: l10n.searchDestHint,
                              city: _dest,
                              cities: cities,
                              icon: Icons.location_on_rounded,
                              onChanged: (c) => setState(() => _dest = c),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Date + passengers row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: context.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.divider),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: context.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat(
                                      'EEE d MMM',
                                      locale,
                                    ).format(_date),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_rounded,
                                    size: 18,
                                  ),
                                  onPressed: _passengers > 1
                                      ? () => setState(() => _passengers--)
                                      : null,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: context.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$_passengers',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  onPressed: _passengers < 9
                                      ? () => setState(() => _passengers++)
                                      : null,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Company filter (optional)
                    if (tenants.isNotEmpty)
                      _CompanyFilter(
                        tenants: tenants,
                        selected: _company,
                        onChanged: (t) => setState(() => _company = t),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFDC2626),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        _loading
                            ? l10n.searchInProgress
                            : l10n.searchButtonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Results ──────────────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _results == null
                  ? _SearchPrompt(key: const ValueKey('prompt'))
                  : _results!.isEmpty
                  ? _NoResults(key: const ValueKey('empty'))
                  : ListView.builder(
                      key: ValueKey(_results!.length),
                      padding: const EdgeInsets.all(16),
                      itemCount: _results!.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        delay: Duration(milliseconds: (i * 55).clamp(0, 220)),
                        child: _SearchResultCard(
                          trip: _results![i],
                          passengers: _passengers,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Company filter row ────────────────────────────────────────────────────────

class _CompanyFilter extends StatelessWidget {
  final List<Tenant> tenants;
  final Tenant? selected;
  final ValueChanged<Tenant?> onChanged;
  const _CompanyFilter({
    required this.tenants,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: tenants.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            final isAll = selected == null;
            return GestureDetector(
              onTap: () => onChanged(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isAll ? brandOrange : context.inputFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAll ? brandOrange : context.divider,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.searchAllCompanies,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAll ? Colors.white : context.textSecondary,
                  ),
                ),
              ),
            );
          }
          final t = tenants[i - 1];
          final isSel = selected?.id == t.id;
          return GestureDetector(
            onTap: () => onChanged(isSel ? null : t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSel
                    ? brandOrange.withValues(alpha: 0.1)
                    : context.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? brandOrange : context.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.logo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        t.logo!,
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.business,
                          size: 14,
                          color: brandOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    Icon(Icons.business, size: 14, color: brandOrange),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel ? brandOrange : context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    required this.label,
    required this.hint,
    required this.city,
    required this.cities,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _showPicker(context),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: city != null ? brandOrange : context.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  city?.name ?? hint,
                  style: TextStyle(
                    color: city != null
                        ? context.textPrimary
                        : context.textMuted,
                    fontWeight: city != null
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
  const _CityPickerSheet({
    required this.title,
    required this.cities,
    required this.onSelected,
  });
  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = widget.cities
        .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchCityHint,
                prefixIcon: const Icon(Icons.search_rounded),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tagBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_city_outlined,
                    color: brandOrange,
                    size: 18,
                  ),
                ),
                title: Text(
                  filtered[i].name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.textPrimary,
                  ),
                ),
                onTap: () => widget.onSelected(filtered[i]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final Trip trip;
  final int passengers;
  const _SearchResultCard({required this.trip, required this.passengers});

  static const _classCfg = {
    'VIP': (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'EXPRESS': (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'STANDARD': (Color(0xFFF0FDF4), Color(0xFF16A34A)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cc = _classCfg[trip.tripClass] ?? _classCfg['STANDARD']!;
    final total = trip.price * passengers;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/passenger/trip/${trip.id}?passengers=$passengers'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company header (tappable)
              if (trip.tenantName != null) ...[
                GestureDetector(
                  onTap: trip.tenantSlug != null
                      ? () => context.push(
                          '/passenger/company/${trip.tenantSlug}',
                        )
                      : null,
                  child: Row(
                    children: [
                      CompanyLogo(logo: trip.tenantLogo, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        trip.tenantName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: trip.tenantSlug != null
                              ? brandOrange
                              : context.textSecondary,
                        ),
                      ),
                      if (trip.tenantSlug != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: brandOrange,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Route + price
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip.originCity} → ${trip.destinationCity}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (trip.departureStationName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: context.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    trip.departureStationName!,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: context.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(trip.departureAt.toLocal()),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.event_seat_outlined,
                              size: 12,
                              color: context.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.searchSeat(trip.availableSeats),
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.price.toStringAsFixed(0)} F',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: brandOrange,
                        ),
                      ),
                      if (passengers > 1)
                        Text(
                          '${l10n.total}: ${total.toStringAsFixed(0)} F',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textMuted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cc.$1,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trip.tripClass,
                          style: TextStyle(
                            color: cc.$2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Intermediate stops row
              if (trip.stops.isNotEmpty) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < trip.stops.length; i++) ...[
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: context.textMuted,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 10,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                trip.stops[i].cityName ?? '?',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (trip.status == 'BOARDING') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.door_front_door_outlined,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.tripStatusBoarding,
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Placeholder states ────────────────────────────────────────────────────────

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.inputFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 36,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchLaunchPrompt,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.searchLaunchSub,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.inputFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 36,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchNoResults,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.searchTryOther,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
