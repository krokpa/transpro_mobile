import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/offline/manifest_cache.dart';
import '../../core/connectivity/offline_badge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ManifestTicket {
  final String id;
  final String seatNumber;
  final DateTime? checkedInAt;
  final String? qrCodeData;
  bool get isCheckedIn => checkedInAt != null;

  const ManifestTicket({
    required this.id,
    required this.seatNumber,
    this.checkedInAt,
    this.qrCodeData,
  });

  factory ManifestTicket.fromJson(Map<String, dynamic> j) => ManifestTicket(
    id: j['id'] as String,
    seatNumber: j['seatNumber'] as String? ?? '—',
    checkedInAt: j['checkedInAt'] != null
        ? DateTime.tryParse(j['checkedInAt'] as String)
        : null,
    qrCodeData: j['qrCodeData'] as String?,
  );
}

class ManifestEntry {
  final String bookingId;
  final String reference;
  final String passengerName;
  final String? phone;
  final String status;
  final List<ManifestTicket> tickets;

  const ManifestEntry({
    required this.bookingId,
    required this.reference,
    required this.passengerName,
    this.phone,
    required this.status,
    required this.tickets,
  });

  int get checkedInCount => tickets.where((t) => t.isCheckedIn).length;
  bool get allCheckedIn =>
      tickets.isNotEmpty && checkedInCount == tickets.length;

  factory ManifestEntry.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : j['passengerName'] as String? ?? 'Passager';

    final rawTickets = j['tickets'] as List? ?? [];
    return ManifestEntry(
      bookingId: j['id'] as String,
      reference: j['reference'] as String? ?? '—',
      passengerName: name.isEmpty ? 'Passager' : name,
      phone: user?['phone'] as String?,
      status: j['status'] as String? ?? 'CONFIRMED',
      tickets: rawTickets
          .map((t) => ManifestTicket.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _manifestProvider = FutureProvider.autoDispose
    .family<List<ManifestEntry>, String>((ref, tripId) async {
      final dio = ref.read(dioProvider);
      try {
        final res = await dio.get('/trips/$tripId/manifest');
        final items = extractData(res.data) as List;
        await ManifestCache.saveManifest(
          tripId,
          items.cast<Map<String, dynamic>>(),
        );
        return items
            .map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        final cached = ManifestCache.getManifest(tripId);
        if (cached != null) {
          return cached.map(ManifestEntry.fromJson).toList();
        }
        rethrow;
      }
    });

final _tripDetailProvider = FutureProvider.autoDispose.family<Trip, String>((
  ref,
  id,
) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/$id');
  return Trip.fromJson(extractData(res.data));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ManifestScreen extends ConsumerStatefulWidget {
  final String tripId;
  const ManifestScreen({super.key, required this.tripId});
  @override
  ConsumerState<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends ConsumerState<ManifestScreen> {
  final _search = TextEditingController();
  String _filter = '';
  final Set<String> _checkingIn = {};
  bool _showMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPending());
  }

  Future<void> _syncPending() async {
    if (!ManifestCache.hasPendingSyncs) return;
    final pending = ManifestCache.getPendingSyncs();
    final dio = ref.read(dioProvider);
    for (final item in pending) {
      final ticketId = item['ticketId'] as String;
      try {
        await dio.patch('/payments/tickets/$ticketId/check-in');
        await ManifestCache.removeSynced(ticketId);
      } catch (_) {}
    }
    if (pending.isNotEmpty && mounted) {
      ref.invalidate(_manifestProvider(widget.tripId));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _checkIn(ManifestTicket ticket) async {
    if (ticket.isCheckedIn || _checkingIn.contains(ticket.id)) return;
    setState(() => _checkingIn.add(ticket.id));
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/payments/tickets/${ticket.id}/check-in');
      ref.invalidate(_manifestProvider(widget.tripId));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _checkingIn.remove(ticket.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tripAsync = ref.watch(_tripDetailProvider(widget.tripId));
    final manifestAsync = ref.watch(_manifestProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: tripAsync.when(
          data: (t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.manifestTitle),
              Text(
                '${t.originCity} → ${t.destinationCity} · ${DateFormat('HH:mm').format(t.departureAt.toLocal())}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          loading: () => Text(l10n.manifestTitle),
          error: (_, _) => Text(l10n.manifestTitle),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: l10n.navScanner,
            onPressed: () =>
                context.push('/agent/scan-ticket?tripId=${widget.tripId}'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_manifestProvider(widget.tripId));
              ref.invalidate(_tripDetailProvider(widget.tripId));
            },
          ),
        ],
      ),
      body: manifestAsync.when(
        loading: () => AppShimmer.manifestTiles(),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (entries) {
          final filtered = _filter.isEmpty
              ? entries
              : entries
                    .where(
                      (e) =>
                          e.passengerName.toLowerCase().contains(_filter) ||
                          e.reference.toLowerCase().contains(_filter) ||
                          e.tickets.any(
                            (t) => t.seatNumber.toLowerCase().contains(_filter),
                          ),
                    )
                    .toList();

          final totalTickets = entries.fold(0, (s, e) => s + e.tickets.length);
          final checkedInTickets = entries.fold(
            0,
            (s, e) => s + e.checkedInCount,
          );
          final missingEntries = entries
              .where((e) => !e.allCheckedIn && e.status == 'CONFIRMED')
              .toList();

          return Column(
            children: [
              const OfflineBadge(),
              Container(
                color: context.cardBg,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StatChip(
                          label: l10n.total,
                          value: '$totalTickets',
                          color: const Color(0xFF64748B),
                          bg: const Color(0xFFF1F5F9),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: l10n.manifestScanned,
                          value: '$checkedInTickets',
                          color: const Color(0xFF16A34A),
                          bg: const Color(0xFFDCFCE7),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: l10n.bookingStatusPending,
                          value: '${totalTickets - checkedInTickets}',
                          color: const Color(0xFFCA8A04),
                          bg: const Color(0xFFFEF9C3),
                        ),
                        const Spacer(),
                        if (totalTickets > 0)
                          SizedBox(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(checkedInTickets / totalTickets * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: brandOrange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: totalTickets > 0
                                        ? checkedInTickets / totalTickets
                                        : 0,
                                    backgroundColor: context.divider,
                                    valueColor: const AlwaysStoppedAnimation(
                                      brandOrange,
                                    ),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      onChanged: (v) =>
                          setState(() => _filter = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: l10n.manifestSearchHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _filter = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              tripAsync.when(
                data: (trip) {
                  final minsToGo = trip.departureAt
                      .difference(DateTime.now())
                      .inMinutes;
                  if (minsToGo > 10 ||
                      minsToGo < -5 ||
                      missingEntries.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _showMissing = !_showMissing),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: const Color(0xFFFEE2E2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.manifestMissingAlert(
                                    missingEntries.length,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                _showMissing
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: const Color(0xFFDC2626),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showMissing)
                        Container(
                          color: const Color(0xFFFFF1F1),
                          child: Column(
                            children: missingEntries
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(
                                            0xFFFEE2E2,
                                          ),
                                          child: Text(
                                            e.passengerName.isNotEmpty
                                                ? e.passengerName[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFDC2626),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.passengerName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: context.textPrimary,
                                                ),
                                              ),
                                              if (e.phone != null)
                                                Text(
                                                  e.phone!,
                                                  style: TextStyle(
                                                    color:
                                                        context.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (e.phone != null)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.phone_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              final uri = Uri(
                                                scheme: 'tel',
                                                path: e.phone,
                                              );
                                              if (await canLaunchUrl(uri))
                                                launchUrl(uri);
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const Divider(height: 1),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 52,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter.isEmpty
                                  ? l10n.manifestNoPassengers
                                  : l10n.noResults,
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(
                          _manifestProvider(widget.tripId).future,
                        ),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (_, i) => _ManifestEntryTile(
                            entry: filtered[i],
                            checkingIn: _checkingIn,
                            onCheckIn: _checkIn,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Entry tile ────────────────────────────────────────────────────────────────

class _ManifestEntryTile extends StatelessWidget {
  final ManifestEntry entry;
  final Set<String> checkingIn;
  final void Function(ManifestTicket) onCheckIn;
  const _ManifestEntryTile({
    required this.entry,
    required this.checkingIn,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final allIn = entry.allCheckedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: allIn
                    ? const Color(0xFFDCFCE7)
                    : context.tagBg,
                child: Text(
                  entry.passengerName.isNotEmpty
                      ? entry.passengerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: allIn ? const Color(0xFF16A34A) : brandOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.passengerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      entry.phone != null
                          ? '${AppLocalizations.of(context).bookingRef}: ${entry.reference}  ·  ${entry.phone}'
                          : '${AppLocalizations.of(context).bookingRef}: ${entry.reference}',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: allIn
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF9C3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  allIn
                      ? AppLocalizations.of(context).manifestScanned
                      : '${entry.checkedInCount}/${entry.tickets.length}',
                  style: TextStyle(
                    color: allIn
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFCA8A04),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (entry.tickets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: entry.tickets.map((t) {
                final isIn = t.isCheckedIn;
                final loading = checkingIn.contains(t.id);
                return GestureDetector(
                  onTap: isIn ? null : () => onCheckIn(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isIn ? const Color(0xFFDCFCE7) : context.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isIn ? const Color(0xFF86EFAC) : context.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: brandOrange,
                            ),
                          )
                        else
                          Icon(
                            isIn
                                ? Icons.check_circle
                                : Icons.event_seat_outlined,
                            size: 14,
                            color: isIn
                                ? const Color(0xFF16A34A)
                                : context.textMuted,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          t.seatNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isIn
                                ? const Color(0xFF16A34A)
                                : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    ),
  );
}
