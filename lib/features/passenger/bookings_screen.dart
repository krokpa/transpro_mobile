import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/offline/ticket_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/fade_slide.dart';
import '../../l10n/app_localizations.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _myBookingsProvider =
    FutureProvider.autoDispose<({List<Booking> bookings, bool isOffline})>(
        (ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/bookings/my');
    final items = extractData(res.data) as List;
    await TicketCache.saveBookingList(items);
    final bookings =
        items.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
    return (bookings: bookings, isOffline: false);
  } catch (_) {
    final cached = TicketCache.getBookings();
    if (cached.isNotEmpty) {
      return (
        bookings: cached.map((e) => Booking.fromJson(e)).toList(),
        isOffline: true
      );
    }
    rethrow;
  }
});

// ── Filter model ──────────────────────────────────────────────────────────────

class _BookingFilter {
  final String? status;
  final String? company;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _BookingFilter({
    this.status,
    this.company,
    this.dateFrom,
    this.dateTo,
  });

  static const _BookingFilter empty = _BookingFilter();

  bool get isActive =>
      status != null || company != null || dateFrom != null || dateTo != null;

  int get activeCount =>
      (status != null ? 1 : 0) +
      (company != null ? 1 : 0) +
      (dateFrom != null || dateTo != null ? 1 : 0);

  _BookingFilter withStatus(String? s) => _BookingFilter(
        status: s,
        company: company,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

  _BookingFilter withCompany(String? c) => _BookingFilter(
        status: status,
        company: c,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

  _BookingFilter withDates(DateTime? from, DateTime? to) => _BookingFilter(
        status: status,
        company: company,
        dateFrom: from,
        dateTo: to,
      );

  List<Booking> apply(List<Booking> all) => all.where((b) {
        if (status != null && b.status != status) return false;
        if (company != null && b.trip?.tenantName != company) return false;
        final date = b.trip?.departureAt ?? b.createdAt;
        if (dateFrom != null && date.isBefore(dateFrom!)) return false;
        if (dateTo != null &&
            date.isAfter(dateTo!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  _BookingFilter _filter = _BookingFilter.empty;

  static const _statuses = [
    ('CONFIRMED', 'Confirmé',  Color(0xFF16A34A), Icons.check_circle_outline),
    ('PENDING',   'En attente', Color(0xFFCA8A04), Icons.schedule_outlined),
    ('COMPLETED', 'Terminé',   Color(0xFF0369A1), Icons.done_all_rounded),
    ('CANCELLED', 'Annulé',    Color(0xFFDC2626), Icons.cancel_outlined),
  ];

  void _openFilterSheet(BuildContext context, List<Booking> allBookings) {
    final companies = allBookings
        .map((b) => b.trip?.tenantName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        initialFilter: _filter,
        companies: companies,
        onApply: (f) => setState(() => _filter = f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final async = ref.watch(_myBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookingsTitle),
        actions: [
          async.whenData((r) => r.bookings).valueOrNull != null
              ? _FilterBadgeButton(
                  count: _filter.activeCount,
                  onTap: () => _openFilterSheet(
                      context, async.value!.bookings),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (result) {
          final allBookings = result.bookings;
          final isOffline   = result.isOffline;

          if (allBookings.isEmpty) return _EmptyState(l10n: l10n);

          final filtered = _filter.apply(allBookings);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_myBookingsProvider.future),
            child: Column(children: [
              // ── Offline banner ──────────────────────────────────────────
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: const Color(0xFFFEF9C3),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 16, color: Color(0xFFCA8A04)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.bookingsOfflineMode,
                        style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),

              // ── Status chips ────────────────────────────────────────────
              _StatusChipsRow(
                selected: _filter.status,
                onSelect: (s) =>
                    setState(() => _filter = _filter.withStatus(s)),
              ),

              // ── Active filter chips (company / date) ────────────────────
              if (_filter.company != null || _filter.dateFrom != null)
                _ActiveFiltersRow(
                  filter: _filter,
                  onRemoveCompany: () =>
                      setState(() => _filter = _filter.withCompany(null)),
                  onRemoveDates: () => setState(
                      () => _filter = _filter.withDates(null, null)),
                ),

              // ── Count ───────────────────────────────────────────────────
              if (_filter.isActive)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _NoFilterResults(
                        onReset: () =>
                            setState(() => _filter = _BookingFilter.empty),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          delay: Duration(
                              milliseconds: (i * 60).clamp(0, 240)),
                          child: _BookingCard(booking: filtered[i]),
                        ),
                      ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Status chips row ──────────────────────────────────────────────────────────

class _StatusChipsRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _StatusChipsRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _StatusChip(
            label: 'Tous',
            icon: Icons.list_rounded,
            color: context.textSecondary,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ..._BookingsScreenState._statuses.map((s) => _StatusChip(
                label: s.$2,
                icon: s.$4,
                color: s.$3,
                selected: selected == s.$1,
                onTap: () => onSelect(selected == s.$1 ? null : s.$1),
              )),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : context.inputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : context.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: selected ? color : context.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : context.textSecondary,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Active filter chips (company, date range) ─────────────────────────────────

class _ActiveFiltersRow extends StatelessWidget {
  final _BookingFilter filter;
  final VoidCallback onRemoveCompany;
  final VoidCallback onRemoveDates;

  const _ActiveFiltersRow({
    required this.filter,
    required this.onRemoveCompany,
    required this.onRemoveDates,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = _buildDateLabel();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12, right: 12),
        children: [
          if (filter.company != null)
            _RemovableChip(
              label: filter.company!,
              onRemove: onRemoveCompany,
            ),
          if (dateLabel != null)
            _RemovableChip(label: dateLabel, onRemove: onRemoveDates),
        ],
      ),
    );
  }

  String? _buildDateLabel() {
    if (filter.dateFrom == null && filter.dateTo == null) return null;
    final fmt = DateFormat('d MMM', 'fr_FR');
    if (filter.dateFrom != null && filter.dateTo != null) {
      return '${fmt.format(filter.dateFrom!)} – ${fmt.format(filter.dateTo!)}';
    }
    if (filter.dateFrom != null) return 'Depuis ${fmt.format(filter.dateFrom!)}';
    return "Jusqu'au ${fmt.format(filter.dateTo!)}";
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: brandOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: brandOrange.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: brandOrange)),
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child:
                    Icon(Icons.close_rounded, size: 14, color: brandOrange),
              ),
            ),
          ]),
        ),
      );
}

// ── Filter badge button ───────────────────────────────────────────────────────

class _FilterBadgeButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FilterBadgeButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: count > 0 ? brandOrange : null,
            ),
            onPressed: onTap,
            tooltip: 'Filtrer',
          ),
          if (count > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: brandOrange,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      );
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _BookingFilter initialFilter;
  final List<String> companies;
  final ValueChanged<_BookingFilter> onApply;

  const _FilterSheet({
    required this.initialFilter,
    required this.companies,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _company;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _company  = widget.initialFilter.company;
    _dateFrom = widget.initialFilter.dateFrom;
    _dateTo   = widget.initialFilter.dateTo;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      locale: const Locale('fr', 'FR'),
      saveText: 'Appliquer',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: brandOrange),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _dateFrom = range.start;
        _dateTo   = range.end;
      });
    }
  }

  void _apply() {
    widget.onApply(widget.initialFilter
        .withCompany(_company)
        .withDates(_dateFrom, _dateTo));
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _company  = null;
      _dateFrom = null;
      _dateTo   = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'fr_FR');
    final hasDate = _dateFrom != null || _dateTo != null;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Text('Filtres avancés',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: context.textPrimary)),
            const Spacer(),
            TextButton(
              onPressed: _reset,
              child: const Text('Réinitialiser',
                  style: TextStyle(color: brandOrange, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Company ──────────────────────────────────────────────────
          if (widget.companies.isNotEmpty) ...[
            Text('Compagnie',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondary,
                    letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.companies
                  .map((c) => _WrapChip(
                        label: c,
                        selected: _company == c,
                        onTap: () => setState(
                            () => _company = _company == c ? null : c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ── Date range ────────────────────────────────────────────────
          Text('Période',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasDate
                    ? brandOrange.withValues(alpha: 0.07)
                    : context.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasDate
                        ? brandOrange.withValues(alpha: 0.35)
                        : context.divider),
              ),
              child: Row(children: [
                Icon(Icons.date_range_outlined,
                    size: 18,
                    color: hasDate ? brandOrange : context.textMuted),
                const SizedBox(width: 10),
                Text(
                  hasDate
                      ? '${_dateFrom != null ? fmt.format(_dateFrom!) : '…'}'
                        ' – ${_dateTo != null ? fmt.format(_dateTo!) : '…'}'
                      : 'Sélectionner une période',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        hasDate ? FontWeight.w600 : FontWeight.normal,
                    color: hasDate ? brandOrange : context.textMuted,
                  ),
                ),
                const Spacer(),
                if (hasDate)
                  GestureDetector(
                    onTap: () =>
                        setState(() {
                          _dateFrom = null;
                          _dateTo   = null;
                        }),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: brandOrange),
                  ),
              ]),
            ),
          ),

          // ── Quick date shortcuts ──────────────────────────────────────
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _DateShortcut(
              label: 'Ce mois',
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _dateFrom = DateTime(now.year, now.month, 1);
                  _dateTo   = DateTime(now.year, now.month + 1, 0);
                });
              },
            ),
            _DateShortcut(
              label: 'Mois dernier',
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _dateFrom = DateTime(now.year, now.month - 1, 1);
                  _dateTo   = DateTime(now.year, now.month, 0);
                });
              },
            ),
            _DateShortcut(
              label: '3 derniers mois',
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _dateFrom =
                      DateTime(now.year, now.month - 3, now.day);
                  _dateTo = now;
                });
              },
            ),
          ]),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              child: const Text('Appliquer les filtres'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _WrapChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WrapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? brandOrange.withValues(alpha: 0.1)
                : context.inputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? brandOrange.withValues(alpha: 0.5)
                  : context.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? brandOrange : context.textSecondary,
            ),
          ),
        ),
      );
}

class _DateShortcut extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateShortcut({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12, color: context.textSecondary)),
        backgroundColor: context.inputFill,
        side: BorderSide(color: context.divider),
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: onTap,
      );
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: context.inputFill, shape: BoxShape.circle),
            child: Icon(Icons.confirmation_num_outlined,
                size: 36, color: context.textMuted),
          ),
          const SizedBox(height: 16),
          Text(l10n.bookingsNoBookings,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text(l10n.bookingsNoBookingsSub,
              style: TextStyle(color: context.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/passenger/search'),
            icon: const Icon(Icons.search_rounded),
            label: Text(l10n.bookingsSearchTrips),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      );
}

class _NoFilterResults extends StatelessWidget {
  final VoidCallback onReset;
  const _NoFilterResults({required this.onReset});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: context.inputFill, shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded,
                size: 32, color: context.textMuted),
          ),
          const SizedBox(height: 14),
          Text('Aucun résultat',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: context.textPrimary)),
          const SizedBox(height: 6),
          Text('Essayez de modifier vos filtres.',
              style: TextStyle(fontSize: 13, color: context.textMuted)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onReset,
            child: const Text('Réinitialiser les filtres',
                style: TextStyle(color: brandOrange)),
          ),
        ]),
      );
}

// ── Booking card (inchangée) ──────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  static const _statusColors = <String, (Color, Color, IconData)>{
    'CONFIRMED': (Color(0xFFDCFCE7), Color(0xFF16A34A), Icons.check_circle_outline),
    'PENDING':   (Color(0xFFFEF9C3), Color(0xFFCA8A04), Icons.schedule_outlined),
    'CANCELLED': (Color(0xFFFEE2E2), Color(0xFFDC2626), Icons.cancel_outlined),
    'COMPLETED': (Color(0xFFF0F9FF), Color(0xFF0369A1), Icons.done_all_rounded),
  };

  String _statusLabel(String status, AppLocalizations l10n) =>
      switch (status) {
        'CONFIRMED' => l10n.bookingStatusConfirmed,
        'PENDING'   => l10n.bookingStatusPending,
        'CANCELLED' => l10n.bookingStatusCancelled,
        'COMPLETED' => l10n.bookingStatusCompleted,
        _           => status,
      };

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context);
    final cfg       = _statusColors[booking.status] ?? _statusColors['PENDING']!;
    final trip      = booking.trip;
    final isPending = booking.status == 'PENDING';
    final isActive  = trip != null &&
        (trip.status == 'BOARDING' || trip.status == 'DEPARTED');
    final locale = Localizations.localeOf(context).toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/passenger/booking/${booking.id}'),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    trip?.routeName ?? '—',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: cfg.$1,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.$3, size: 12, color: cfg.$2),
                    const SizedBox(width: 4),
                    Text(_statusLabel(booking.status, l10n),
                        style: TextStyle(
                            color: cfg.$2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (trip != null) ...[
                const SizedBox(height: 4),
                // Company name
                if (trip.tenantName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.business_outlined,
                          size: 12, color: context.textMuted),
                      const SizedBox(width: 4),
                      Text(trip.tenantName!,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE d MMM yyyy • HH:mm', locale)
                        .format(trip.departureAt.toLocal()),
                    style: TextStyle(
                        color: context.textSecondary, fontSize: 12),
                  ),
                ]),
              ],
              const Divider(height: 18),
              Row(children: [
                Icon(Icons.confirmation_num_outlined,
                    size: 14, color: context.textMuted),
                const SizedBox(width: 6),
                Text(booking.reference,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace')),
                const Spacer(),
                Text(
                  '${booking.totalAmount.toStringAsFixed(0)} F',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: brandOrange,
                      fontSize: 15),
                ),
              ]),
            ]),
          ),

          if (isPending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF9C3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.payments_outlined,
                    size: 14, color: Color(0xFFCA8A04)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.bookingsPendingPay,
                      style: const TextStyle(
                          color: Color(0xFFCA8A04),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: Color(0xFFCA8A04)),
              ]),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                    '/passenger/booking/${booking.id}/luggage?ref=${booking.reference}'),
                icon: const Icon(Icons.luggage_outlined, size: 15),
                label: const Text('Mes bagages'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          if (isActive && !isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/track/${trip.id}'),
                  icon: Icon(
                    trip.status == 'DEPARTED'
                        ? Icons.moving_rounded
                        : Icons.directions_bus_filled_rounded,
                    size: 16,
                  ),
                  label: Text(
                    trip.status == 'DEPARTED'
                        ? l10n.bookingsTrackLive
                        : l10n.bookingsTrackBoarding,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: trip.status == 'DEPARTED'
                        ? const Color(0xFF16A34A)
                        : brandOrange,
                    side: BorderSide(
                      color: trip.status == 'DEPARTED'
                          ? const Color(0xFF16A34A)
                          : brandOrange,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
