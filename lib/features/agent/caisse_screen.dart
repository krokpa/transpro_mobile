import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final _caisseProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, dateStr) async {
  final user = ref.read(authProvider).user!;
  final dio  = ref.read(dioProvider);
  final res  = await dio.get('/stations/${user.stationId}/caisse', queryParameters: {'date': dateStr});
  return res.data as Map<String, dynamic>;
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
    final async = ref.watch(_caisseProvider(_dateStr));
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == _dateStr;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rapport de caisse'),
          Text(ref.read(authProvider).user?.stationName ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8))),
        ]),
      ),
      body: Column(children: [
        // Date nav
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
            Expanded(child: Text(
              isToday ? 'Aujourd\'hui — ${DateFormat('d MMM', 'fr_FR').format(_date)}'
                      : DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_date),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday ? null : () => _changeDay(1),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
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
    final revenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0;
    final billets = (data['totalTickets'] as num?)?.toInt() ?? 0;
    final passengers = (data['totalPassengers'] as num?)?.toInt() ?? 0;
    final methods = (data['byMethod'] as List?) ?? [];
    final transactions = (data['transactions'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // KPIs
        Row(children: [
          Expanded(child: _KpiCard(
            label: 'Recettes', value: '${_fmt(revenue)} F',
            icon: Icons.payments_outlined, color: brandOrange,
          )),
          const SizedBox(width: 12),
          Expanded(child: _KpiCard(
            label: 'Billets', value: '$billets',
            icon: Icons.confirmation_num_outlined, color: const Color(0xFF6366F1),
          )),
          const SizedBox(width: 12),
          Expanded(child: _KpiCard(
            label: 'Passagers', value: '$passengers',
            icon: Icons.people_outline, color: const Color(0xFF0EA5E9),
          )),
        ]),
        const SizedBox(height: 20),

        // By payment method
        if (methods.isNotEmpty) ...[
          const Text('Par mode de paiement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
          const SizedBox(height: 10),
          ...methods.map((m) {
            final amt = (m['amount'] as num?)?.toDouble() ?? 0;
            final pct = revenue > 0 ? amt / revenue : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(children: [
                Row(children: [
                  Text(_methodLabel(m['method']), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${_fmt(amt)} F', style: const TextStyle(fontWeight: FontWeight.w600, color: brandDark)),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct, minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(brandOrange),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Transactions
        if (transactions.isNotEmpty) ...[
          const Text('Transactions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandDark)),
          const SizedBox(height: 10),
          ...transactions.map((t) => _TransactionTile(tx: t)),
        ] else
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('Aucune transaction', style: TextStyle(color: Colors.grey[400])),
          )),
      ]),
    );
  }

  String _fmt(double v) => NumberFormat('#,###', 'fr_FR').format(v.toInt());
  String _methodLabel(String? m) => {
    'CASH': 'Espèces', 'ORANGE_MONEY': 'Orange Money',
    'MTN_MOMO': 'MTN MoMo', 'WAVE': 'Wave',
  }[m] ?? m ?? '—';
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
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]),
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final time = tx['createdAt'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()) : '—';
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx['booking']?['reference'] ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
          Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ]),
        const Spacer(),
        Text('${NumberFormat('#,###', 'fr_FR').format(amt.toInt())} F',
          style: const TextStyle(fontWeight: FontWeight.w700, color: brandDark)),
      ]),
    );
  }
}
