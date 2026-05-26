import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final _revenueProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/reports/revenue', queryParameters: {'period': period});
  return res.data as Map<String, dynamic>;
});

final _bookingsReportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/reports/bookings', queryParameters: {'period': period});
  return res.data as Map<String, dynamic>;
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = '30d';
  bool _exporting = false;

  static const _periods = [
    ('7d',  '7 jours'),
    ('30d', '30 jours'),
    ('90d', '3 mois'),
    ('365d','1 an'),
  ];

  final _fmt = NumberFormat('#,###', 'fr_FR');

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/reports/export',
        queryParameters: {'period': _period, 'format': format},
      );
      final data = res.data;
      final map = data is Map<String, dynamic> ? data : null;
      final content = data is String ? data
          : map?['url'] as String? ?? map?['data'] as String? ?? '';
      if (content.isNotEmpty) {
        await Share.share(content, subject: 'Rapport TransPro ($format)');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export impossible: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final revenueAsync  = ref.watch(_revenueProvider(_period));
    final bookingsAsync = ref.watch(_bookingsReportProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_revenueProvider(_period));
              ref.invalidate(_bookingsReportProvider(_period));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_revenueProvider(_period));
          ref.invalidate(_bookingsReportProvider(_period));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Period picker
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final sel = _period == p.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.$2),
                      selected: sel,
                      onSelected: (_) {
                        setState(() => _period = p.$1);
                        ref.invalidate(_revenueProvider(p.$1));
                        ref.invalidate(_bookingsReportProvider(p.$1));
                      },
                      selectedColor: brandOrange,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF64748B),
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Revenue section
            const Text('Recettes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: brandDark)),
            const SizedBox(height: 10),
            revenueAsync.when(
              loading: () => const _SkeletonCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (data) => Column(children: [
                Row(children: [
                  Expanded(child: _KpiCard(
                    label: 'Total recettes',
                    value: '${_fmt.format((data['total'] as num?)?.toInt() ?? 0)} F',
                    icon: Icons.payments_outlined,
                    color: brandOrange,
                    bg: brandLight,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiCard(
                    label: 'Transactions',
                    value: '${(data['count'] as num?)?.toInt() ?? 0}',
                    icon: Icons.receipt_outlined,
                    color: const Color(0xFF2563EB),
                    bg: const Color(0xFFEFF6FF),
                  )),
                ]),
                const SizedBox(height: 10),
                if (data['byPaymentMethod'] != null)
                  _PaymentBreakdown(data: data['byPaymentMethod'] as Map<String, dynamic>),
              ]),
            ),
            const SizedBox(height: 20),

            // Bookings section
            const Text('Réservations',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: brandDark)),
            const SizedBox(height: 10),
            bookingsAsync.when(
              loading: () => const _SkeletonCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (data) => Column(children: [
                Row(children: [
                  Expanded(child: _KpiCard(
                    label: 'Total réservations',
                    value: '${(data['total'] as num?)?.toInt() ?? 0}',
                    icon: Icons.confirmation_num_outlined,
                    color: const Color(0xFF16A34A),
                    bg: const Color(0xFFDCFCE7),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _KpiCard(
                    label: 'Annulées',
                    value: '${(data['cancelled'] as num?)?.toInt() ?? 0}',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFDC2626),
                    bg: const Color(0xFFFEE2E2),
                  )),
                ]),
                if (data['byStatus'] != null) ...[
                  const SizedBox(height: 10),
                  _StatusBreakdown(data: data['byStatus'] as Map<String, dynamic>),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // Export buttons
            const Text('Exporter',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: brandDark)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _exporting ? null : () => _export('csv'),
                icon: _exporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandOrange,
                  side: const BorderSide(color: brandOrange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: _exporting ? null : () => _export('pdf'),
                icon: _exporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
    ]),
  );
}

class _PaymentBreakdown extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PaymentBreakdown({required this.data});

  static const _labels = {
    'CASH': 'Espèces',
    'ORANGE_MONEY': 'Orange Money',
    'MTN_MOMO': 'MTN MoMo',
    'WAVE': 'Wave',
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'fr_FR');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Par mode de paiement',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: brandDark)),
          const SizedBox(height: 10),
          ...data.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(_labels[e.key] ?? e.key, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text('${fmt.format((e.value as num?)?.toInt() ?? 0)} F',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark)),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatusBreakdown({required this.data});

  static const _labels = {
    'CONFIRMED': ('Confirmées', Color(0xFF16A34A)),
    'PENDING':   ('En attente', Color(0xFFCA8A04)),
    'CANCELLED': ('Annulées',   Color(0xFFDC2626)),
    'COMPLETED': ('Terminées',  Color(0xFF0369A1)),
  };

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Par statut',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: brandDark)),
        const SizedBox(height: 10),
        ...data.entries.map((e) {
          final cfg = _labels[e.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: cfg?.$2 ?? Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(width: 8),
              Text(cfg?.$1 ?? e.key, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text('${(e.value as num?)?.toInt() ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          );
        }),
      ]),
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 100,
    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
    child: const Center(child: CircularProgressIndicator()),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
    child: Text(message, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
  );
}
