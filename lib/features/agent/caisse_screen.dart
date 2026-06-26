import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/payment_logo.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

final _caisseProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, dateStr) async {
  final user = ref.read(authProvider).user!;
  final dio  = ref.read(dioProvider);
  final res  = await dio.get('/stations/${user.stationId}/caisse', queryParameters: {'date': dateStr});
  return extractData(res.data) as Map<String, dynamic>;
});

class CaisseScreen extends ConsumerStatefulWidget {
  const CaisseScreen({super.key});
  @override
  ConsumerState<CaisseScreen> createState() => _State();
}

class _State extends ConsumerState<CaisseScreen> {
  DateTime _date = DateTime.now();

  void _changeDay(int delta) => setState(() => _date = _date.add(Duration(days: delta)));

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context);
    final locale  = Localizations.localeOf(context).toString();
    final async   = ref.watch(_caisseProvider(_dateStr));
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == _dateStr;
    final user    = ref.read(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (user != null) ...[
              UserAvatarWidget(
                firstName: user.firstName,
                lastName: user.lastName,
                avatar: user.avatar,
                size: 34,
              ),
              const SizedBox(width: 10),
            ],
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.caisseDailyReport),
              if (user?.stationName != null)
                Text(
                  user!.stationName!,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: context.textMuted),
                ),
            ]),
          ],
        ),
      ),
      body: Column(children: [
        // ── Date navigator ────────────────────────────────────────────────────
        Container(
          color: context.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDay(-1),
              style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    isToday ? l10n.caisseTodayLabel : DateFormat('EEEE', locale).format(_date),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isToday ? brandOrange : context.textPrimary,
                    ),
                  ),
                  Text(
                    isToday
                        ? DateFormat('d MMMM yyyy', locale).format(_date)
                        : DateFormat('d MMMM yyyy', locale).format(_date),
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: isToday ? context.divider : null,
              ),
              onPressed: isToday ? null : () => _changeDay(1),
              style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: async.when(
          loading: () => AppShimmer.listTiles(),
          error: (e, _) => Center(child: Text('${l10n.error}: $e')),
          data: (data) => _CaisseContent(data: data),
        )),
      ]),
    );
  }
}

class _CaisseContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CaisseContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context);
    final locale     = Localizations.localeOf(context).toString();
    final revenue    = (data['totalRevenue'] as num?)?.toDouble() ?? 0;
    final billets    = (data['totalTickets'] as num?)?.toInt() ?? 0;
    final passengers = (data['totalPassengers'] as num?)?.toInt() ?? 0;
    final methods    = (data['byMethod'] as List?) ?? [];
    final transactions = (data['transactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _KpiCard(
            label: l10n.caisseRevenueLabel,
            value: '${_fmt(revenue, locale)} F',
            icon: Icons.payments_outlined, color: brandOrange,
          )),
          const SizedBox(width: 12),
          Expanded(child: _KpiCard(
            label: l10n.caisseTicketsLabel,
            value: '$billets',
            icon: Icons.confirmation_num_outlined, color: const Color(0xFF6366F1),
          )),
          const SizedBox(width: 12),
          Expanded(child: _KpiCard(
            label: l10n.dashboardPassengers,
            value: '$passengers',
            icon: Icons.people_outline, color: const Color(0xFF0EA5E9),
          )),
        ]),
        const SizedBox(height: 20),

        if (methods.isNotEmpty) ...[
          Text(l10n.caisseByMethod,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
          const SizedBox(height: 10),
          ...methods.map((m) {
            final amt = (m['amount'] as num?)?.toDouble() ?? 0;
            final pct = revenue > 0 ? amt / revenue : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(children: [
                Row(children: [
                  PaymentLogo(method: m['method'] as String? ?? 'CASH', size: 22),
                  const SizedBox(width: 8),
                  Text(_methodLabel(m['method'], l10n),
                      style: TextStyle(fontWeight: FontWeight.w500, color: context.textPrimary)),
                  const Spacer(),
                  Text('${_fmt(amt, locale)} F',
                      style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: context.textMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 6,
                    backgroundColor: context.divider,
                    valueColor: const AlwaysStoppedAnimation(brandOrange),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        if (transactions.isNotEmpty) ...[
          Text(l10n.caisseTransactionsLabel,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
          const SizedBox(height: 10),
          ...transactions.map((t) => _TransactionTile(tx: t)),
        ] else
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(l10n.caisseNoTransactions, style: TextStyle(color: context.textMuted)),
          )),
      ]),
    );
  }

  static String _fmt(double v, String locale) => NumberFormat('#,###', locale).format(v.toInt());

  static String _methodLabel(String? m, AppLocalizations l10n) => switch (m) {
    'CASH'         => l10n.payMethodCash,
    'ORANGE_MONEY' => 'Orange Money',
    'MTN_MOMO'     => 'MTN MoMo',
    'WAVE'         => 'Wave',
    _              => m ?? '—',
  };
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: context.textMuted)),
      ]),
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final time = tx['createdAt'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()) : '—';
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx['booking']?['reference'] ?? '—',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                fontFamily: 'monospace', color: context.textPrimary)),
          Text(time, style: TextStyle(color: context.textMuted, fontSize: 12)),
        ]),
        const Spacer(),
        Text('${NumberFormat('#,###', locale).format(amt.toInt())} F',
          style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
      ]),
    );
  }
}
