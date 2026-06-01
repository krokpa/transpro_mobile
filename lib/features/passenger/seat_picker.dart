import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

final _seatsProvider = FutureProvider.autoDispose
    .family<List<TripSeat>, String>((ref, tripId) async {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/trips/$tripId/seats');
      final items = extractData(res.data);
      return (items as List).map((e) => TripSeat.fromJson(e)).toList();
    });

/// Opens a bottom sheet for seat selection.
/// Returns the list of selected seat numbers, or null if dismissed.
Future<List<String>?> showSeatPicker({
  required BuildContext context,
  required String tripId,
  required int maxSeats,
  required double pricePerSeat,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SeatPickerSheet(
      tripId: tripId,
      maxSeats: maxSeats,
      pricePerSeat: pricePerSeat,
    ),
  );
}

class SeatPickerSheet extends ConsumerStatefulWidget {
  final String tripId;
  final int maxSeats;
  final double pricePerSeat;
  const SeatPickerSheet({
    super.key,
    required this.tripId,
    required this.maxSeats,
    required this.pricePerSeat,
  });

  @override
  ConsumerState<SeatPickerSheet> createState() => _SeatPickerSheetState();
}

class _SeatPickerSheetState extends ConsumerState<SeatPickerSheet> {
  final Set<String> _selected = {};

  void _toggle(TripSeat seat) {
    if (!seat.isAvailable) return;
    setState(() {
      if (_selected.contains(seat.seatNumber)) {
        _selected.remove(seat.seatNumber);
      } else if (_selected.length < widget.maxSeats) {
        _selected.add(seat.seatNumber);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final seatsAsync = ref.watch(_seatsProvider(widget.tripId));
    final total = _selected.length * widget.pricePerSeat;
    final fmt = NumberFormat('#,###', locale);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.seatPickerTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.maxSeats > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.tagBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selected.length}/${widget.maxSeats}',
                      style: const TextStyle(
                        color: brandOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _LegendDot(
                  color: context.cardBg,
                  border: context.divider,
                  label: l10n.seatAvailableLabel,
                ),
                const SizedBox(width: 16),
                _LegendDot(color: brandOrange, label: l10n.seatSelectedLabel),
                const SizedBox(width: 16),
                _LegendDot(
                  color: context.divider,
                  label: l10n.seatOccupiedLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Seat grid
          Expanded(
            child: seatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (seats) => _SeatGrid(
                seats: seats,
                selected: _selected,
                onTap: _toggle,
                controller: controller,
              ),
            ),
          ),
          // Confirm button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
                child: _selected.isEmpty
                    ? Text(l10n.seatSelectMin)
                    : Text(
                        l10n.seatConfirmButton(
                          _selected.length,
                          fmt.format(total.toInt()),
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

// ── Seat grid ─────────────────────────────────────────────────────────────────

class _SeatGrid extends StatelessWidget {
  final List<TripSeat> seats;
  final Set<String> selected;
  final void Function(TripSeat) onTap;
  final ScrollController controller;
  const _SeatGrid({
    required this.seats,
    required this.selected,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sort and group seats into rows of 4 (left: A/B, right: C/D)
    final sorted = [...seats]..sort(_compareSeat);
    final rows = _groupIntoRows(sorted);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Driver area indicator
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: context.inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.drive_eta_outlined,
                size: 18,
                color: context.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.seatFrontOfBus,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        // Seat rows
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Left pair (seats 0 and 1)
                if (row.isNotEmpty)
                  Expanded(
                    child: _SeatButton(
                      seat: row[0],
                      selected: selected,
                      onTap: onTap,
                    ),
                  ),
                const SizedBox(width: 4),
                if (row.length > 1)
                  Expanded(
                    child: _SeatButton(
                      seat: row[1],
                      selected: selected,
                      onTap: onTap,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                // Aisle
                const SizedBox(width: 16),
                // Right pair (seats 2 and 3)
                if (row.length > 2)
                  Expanded(
                    child: _SeatButton(
                      seat: row[2],
                      selected: selected,
                      onTap: onTap,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 4),
                if (row.length > 3)
                  Expanded(
                    child: _SeatButton(
                      seat: row[3],
                      selected: selected,
                      onTap: onTap,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Group flat seat list into rows of 4
  List<List<TripSeat>> _groupIntoRows(List<TripSeat> seats) {
    final rows = <List<TripSeat>>[];
    for (var i = 0; i < seats.length; i += 4) {
      rows.add(seats.sublist(i, (i + 4).clamp(0, seats.length)));
    }
    return rows;
  }

  // Sort: numeric part first, then letter part
  static int _compareSeat(TripSeat a, TripSeat b) {
    final aRow = _rowOf(a.seatNumber);
    final bRow = _rowOf(b.seatNumber);
    if (aRow != bRow) return aRow.compareTo(bRow);
    return _colOf(a.seatNumber).compareTo(_colOf(b.seatNumber));
  }

  static int _rowOf(String s) =>
      int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  static String _colOf(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
}

class _SeatButton extends StatelessWidget {
  final TripSeat seat;
  final Set<String> selected;
  final void Function(TripSeat) onTap;
  const _SeatButton({
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected.contains(seat.seatNumber);
    final isAvailable = seat.isAvailable;

    final Color bg = isSelected
        ? brandOrange
        : isAvailable
        ? context.cardBg
        : context.divider;
    final Color fg = isSelected
        ? Colors.white
        : isAvailable
        ? context.textPrimary
        : context.textMuted;

    return GestureDetector(
      onTap: () => onTap(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? brandOrange : context.divider),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandOrange.withAlpha(60),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          seat.seatNumber,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;
  const _LegendDot({required this.color, this.border, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: border != null ? Border.all(color: border!) : null,
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary)),
    ],
  );
}
