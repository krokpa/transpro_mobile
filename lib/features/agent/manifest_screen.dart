import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ManifestTicket {
  final String id;
  final String seatNumber;
  final DateTime? checkedInAt;
  bool get isCheckedIn => checkedInAt != null;

  const ManifestTicket({required this.id, required this.seatNumber, this.checkedInAt});

  factory ManifestTicket.fromJson(Map<String, dynamic> j) => ManifestTicket(
    id:          j['id'] as String,
    seatNumber:  j['seatNumber'] as String? ?? '—',
    checkedInAt: j['checkedInAt'] != null ? DateTime.tryParse(j['checkedInAt']) : null,
  );
}

class ManifestEntry {
  final String bookingId;
  final String reference;
  final String passengerName;
  final String status;
  final List<ManifestTicket> tickets;

  const ManifestEntry({
    required this.bookingId,
    required this.reference,
    required this.passengerName,
    required this.status,
    required this.tickets,
  });

  int get checkedInCount => tickets.where((t) => t.isCheckedIn).length;
  bool get allCheckedIn  => tickets.isNotEmpty && checkedInCount == tickets.length;

  factory ManifestEntry.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim()
        : j['passengerName'] as String? ?? 'Passager';

    final rawTickets = j['tickets'] as List? ?? [];
    return ManifestEntry(
      bookingId:     j['id'] as String,
      reference:     j['reference'] as String? ?? '—',
      passengerName: name.isEmpty ? 'Passager' : name,
      status:        j['status'] as String? ?? 'CONFIRMED',
      tickets:       rawTickets.map((t) => ManifestTicket.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _manifestProvider = FutureProvider.autoDispose.family<List<ManifestEntry>, String>((ref, tripId) async {
  final dio   = ref.read(dioProvider);
  final res   = await dio.get('/trips/$tripId/manifest');
  final items = extractData(res.data);
  return (items as List).map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>)).toList();
});

final _tripDetailProvider = FutureProvider.autoDispose.family<Trip, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/$id');
  return Trip.fromJson(res.data);
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

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _checkIn(ManifestTicket ticket) async {
    if (ticket.isCheckedIn || _checkingIn.contains(ticket.id)) return;
    setState(() => _checkingIn.add(ticket.id));
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/tickets/${ticket.id}/check-in');
      ref.invalidate(_manifestProvider(widget.tripId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _checkingIn.remove(ticket.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync     = ref.watch(_tripDetailProvider(widget.tripId));
    final manifestAsync = ref.watch(_manifestProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: tripAsync.when(
          data: (t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Manifeste'),
            Text('${t.originCity} → ${t.destinationCity} · ${DateFormat('HH:mm').format(t.departureAt.toLocal())}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8))),
          ]),
          loading: () => const Text('Manifeste'),
          error: (_, __) => const Text('Manifeste'),
        ),
        actions: [
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (entries) {
          final filtered = _filter.isEmpty
              ? entries
              : entries.where((e) =>
                  e.passengerName.toLowerCase().contains(_filter) ||
                  e.reference.toLowerCase().contains(_filter) ||
                  e.tickets.any((t) => t.seatNumber.toLowerCase().contains(_filter)),
                ).toList();

          final totalTickets    = entries.fold(0, (s, e) => s + e.tickets.length);
          final checkedInTickets = entries.fold(0, (s, e) => s + e.checkedInCount);

          return Column(children: [
            // Stats + search
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(children: [
                // Stats row
                Row(children: [
                  _StatChip(
                    label: 'Total',
                    value: '$totalTickets',
                    color: const Color(0xFF64748B),
                    bg: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Embarqués',
                    value: '$checkedInTickets',
                    color: const Color(0xFF16A34A),
                    bg: const Color(0xFFDCFCE7),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'En attente',
                    value: '${totalTickets - checkedInTickets}',
                    color: const Color(0xFFCA8A04),
                    bg: const Color(0xFFFEF9C3),
                  ),
                  const Spacer(),
                  // Progress
                  if (totalTickets > 0)
                    SizedBox(
                      width: 80,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(
                          '${(checkedInTickets / totalTickets * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: brandOrange),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalTickets > 0 ? checkedInTickets / totalTickets : 0,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(brandOrange),
                            minHeight: 5,
                          ),
                        ),
                      ]),
                    ),
                ]),
                const SizedBox(height: 10),
                // Search field
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _filter = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un passager ou un siège…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () { _search.clear(); setState(() => _filter = ''); },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_search_outlined, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filter.isEmpty ? 'Aucun passager' : 'Aucun résultat',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(_manifestProvider(widget.tripId).future),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) => _ManifestEntryTile(
                          entry:      filtered[i],
                          checkingIn: _checkingIn,
                          onCheckIn:  _checkIn,
                        ),
                      ),
                    ),
            ),
          ]);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: allIn ? const Color(0xFFDCFCE7) : brandLight,
            child: Text(
              entry.passengerName.isNotEmpty ? entry.passengerName[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: allIn ? const Color(0xFF16A34A) : brandOrange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.passengerName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: brandDark)),
            Text('Réf: ${entry.reference}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ])),
          // Overall badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: allIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              allIn ? 'Embarqué' : '${entry.checkedInCount}/${entry.tickets.length}',
              style: TextStyle(
                color: allIn ? const Color(0xFF16A34A) : const Color(0xFFCA8A04),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ]),
        // Ticket chips
        if (entry.tickets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: entry.tickets.map((t) {
            final isIn = t.isCheckedIn;
            final loading = checkingIn.contains(t.id);
            return GestureDetector(
              onTap: isIn ? null : () => onCheckIn(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isIn ? const Color(0xFFDCFCE7) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isIn ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (loading)
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: brandOrange),
                    )
                  else
                    Icon(
                      isIn ? Icons.check_circle : Icons.event_seat_outlined,
                      size: 14,
                      color: isIn ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    t.seatNumber,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isIn ? const Color(0xFF16A34A) : brandDark,
                    ),
                  ),
                ]),
              ),
            );
          }).toList()),
        ],
      ]),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatChip({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ]),
  );
}
