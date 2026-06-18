import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo.dart';
import '../../core/widgets/fade_slide.dart';
import '../../core/widgets/shimmer.dart';
import '../../l10n/app_localizations.dart';

// ── Provider ───────────────────────────────────────────────────────────────────

final _transactionsProvider = FutureProvider.autoDispose<List<Payment>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/payments/my');
  final items = extractData(res.data) as List;
  return items.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'ALL';

  static const _filters = ['ALL', 'SUCCESS', 'FAILED', 'PROCESSING'];

  List<Payment> _apply(List<Payment> all) {
    if (_filter == 'ALL') return all;
    return all.where((p) => p.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final async = ref.watch(_transactionsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(l10n.transactionsTitle),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => AppShimmer.listTiles(),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: context.textMuted),
            const SizedBox(height: 12),
            Text(
              apiErrorMessage(e),
              style: TextStyle(color: context.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.invalidate(_transactionsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (all) {
          final filtered = _apply(all);
          final totalSpent = all
              .where((p) => p.isSuccess)
              .fold<double>(0, (sum, p) => sum + p.amount);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_transactionsProvider.future),
            child: CustomScrollView(
              slivers: [
                // ── Summary card ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SummaryCard(
                      totalSpent: totalSpent,
                      count: all.length,
                      l10n: l10n,
                    ),
                  ),
                ),

                // ── Filter chips ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        spacing: 8,
                        children: _filters.map((f) {
                          final selected = _filter == f;
                          return FilterChip(
                            label: Text(_filterLabel(f, l10n)),
                            selected: selected,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor: brandOrange.withValues(alpha: 0.15),
                            checkmarkColor: brandOrange,
                            labelStyle: TextStyle(
                              color: selected ? brandOrange : context.textSecondary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // ── Empty state ───────────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: context.inputFill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 32,
                            color: context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.transactionsEmpty,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.transactionsEmptySub,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textMuted,
                          ),
                        ),
                      ]),
                    ),
                  )
                else
                  // ── Transaction list ────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => FadeSlideIn(
                        delay: Duration(milliseconds: (i * 50).clamp(0, 200)),
                        child: _TransactionCard(
                          payment: filtered[i],
                          l10n: l10n,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _filterLabel(String f, AppLocalizations l10n) => switch (f) {
    'SUCCESS'    => l10n.transactionsFilterSuccess,
    'FAILED'     => l10n.transactionsFilterFailed,
    'PROCESSING' => l10n.transactionsFilterPending,
    _            => l10n.transactionsFilterAll,
  };
}

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalSpent;
  final int count;
  final AppLocalizations l10n;
  const _SummaryCard({required this.totalSpent, required this.count, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandOrange, Color(0xFFE8430E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.transactionsTotalSpent,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(totalSpent.toInt())} FCFA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.transactionsCount(count),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ── Transaction card ───────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Payment payment;
  final AppLocalizations l10n;
  const _TransactionCard({required this.payment, required this.l10n});

  static const _statusCfg = <String, (Color bg, Color fg, IconData icon)>{
    'SUCCESS':    (Color(0xFFDCFCE7), Color(0xFF16A34A), Icons.check_circle_outline),
    'FAILED':     (Color(0xFFFEE2E2), Color(0xFFDC2626), Icons.cancel_outlined),
    'PROCESSING': (Color(0xFFEFF6FF), Color(0xFF2563EB), Icons.hourglass_top_rounded),
    'PENDING':    (Color(0xFFFEF9C3), Color(0xFFCA8A04), Icons.schedule_outlined),
  };

  (Color, Color, IconData) get _cfg =>
      _statusCfg[payment.status] ?? _statusCfg['PENDING']!;

  String _statusLabel(AppLocalizations l10n) => switch (payment.status) {
    'SUCCESS'    => l10n.transactionsStatusSuccess,
    'FAILED'     => l10n.transactionsStatusFailed,
    'PROCESSING' => l10n.transactionsStatusProcessing,
    _            => l10n.transactionsStatusPending,
  };

  String _methodLabel(AppLocalizations l10n) => switch (payment.method) {
    'CASH'         => l10n.transactionsMethodCash,
    'MOBILE_MONEY' => l10n.transactionsMethodMobile,
    'CARD'         => l10n.transactionsMethodCard,
    _              => payment.method,
  };

  IconData get _methodIcon => switch (payment.method) {
    'CASH'         => Icons.payments_outlined,
    'MOBILE_MONEY' => Icons.phone_android_rounded,
    _              => Icons.credit_card_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final cfg    = _cfg;
    final date   = payment.paidAt ?? payment.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: route + amount ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method icon pill
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_methodIcon, size: 20, color: context.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.routeName ??
                            (payment.originCity != null
                                ? '${payment.originCity} → ${payment.destinationCity}'
                                : '—'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (payment.tenantName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CompanyLogo(logo: payment.tenantLogo, size: 16),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                payment.tenantName!,
                                style: TextStyle(fontSize: 12, color: context.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount
                Text(
                  '${NumberFormat('#,###', 'fr_FR').format(payment.amount.toInt())} F',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: payment.isSuccess ? const Color(0xFF16A34A) : context.textPrimary,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // ── Detail rows ─────────────────────────────────────────────────
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cfg.$1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cfg.$3, size: 11, color: cfg.$2),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabel(l10n),
                      style: TextStyle(
                        color: cfg.$2,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                // Method label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.inputFill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _methodLabel(l10n),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Date
                Text(
                  DateFormat('d MMM yyyy', locale).format(date.toLocal()),
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),

            if (payment.bookingReference != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.confirmation_num_outlined, size: 13, color: context.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    l10n.transactionsRef(payment.bookingReference!),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (payment.seatNumbers.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.event_seat_outlined, size: 13, color: context.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      l10n.transactionsSeats(payment.seatNumbers.length),
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ],
              ),
            ],

            if (payment.tripDepartureAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: context.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('EEE d MMM yyyy • HH:mm', locale)
                        .format(payment.tripDepartureAt!.toLocal()),
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ],

            // Fail reason
            if (payment.isFailed && payment.failReason != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payment.failReason!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
