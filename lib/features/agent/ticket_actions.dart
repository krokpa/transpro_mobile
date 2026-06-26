import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/phone_input_field.dart';

/// Actions de remise du billet au client après une vente guichet :
///  • Afficher le QR (le client le scanne / capture depuis l'écran de l'agent)
///  • Envoyer le billet par SMS (lien de récupération universel)
///
/// [booking] est la réponse de POST /bookings/guichet (contient id, reference,
/// tickets[] et éventuellement passenger.phone).
class TicketActions extends StatelessWidget {
  final Map<String, dynamic> booking;
  const TicketActions({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final tickets = (booking['tickets'] as List?) ?? const [];
    final phone = (booking['passenger'] as Map?)?['phone'] as String?;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: tickets.isEmpty
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => _QrSheet(booking: booking),
                    ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Afficher le QR au client'),
            style: OutlinedButton.styleFrom(
              foregroundColor: brandOrange,
              side: BorderSide(color: brandOrange.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              builder: (_) => _SendSmsSheet(
                bookingId: '${booking['id']}',
                initialPhone: phone,
              ),
            ),
            icon: const Icon(Icons.sms_outlined, size: 18),
            label: Text(phone != null && phone.isNotEmpty
                ? 'Renvoyer le billet par SMS'
                : 'Envoyer le billet par SMS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0x552563EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Feuille : afficher le(s) QR ────────────────────────────────────────────────

class _QrSheet extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _QrSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final tickets = (booking['tickets'] as List?) ?? const [];
    final ref = booking['reference'] as String? ?? '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Billet — $ref',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text('Le client scanne ce QR ou en fait une capture',
                style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: 16),
            ...tickets.asMap().entries.map((e) {
              final t = e.value as Map;
              final qrData = t['qrCodeData'] as String? ?? t['qrCode'] as String? ?? '';
              if (qrData.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(children: [
                  if (tickets.length > 1)
                    Text('Siège ${t['seatNumber'] ?? e.key + 1}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.divider),
                    ),
                    child: QrImageView(data: qrData, size: 220),
                  ),
                ]),
              );
            }),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  final link = '$kPublicWebUrl/ticket/$ref';
                  Share.share('Votre billet — Réf $ref\n$link');
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Partager le lien'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Feuille : envoyer par SMS ──────────────────────────────────────────────────

class _SendSmsSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String? initialPhone;
  const _SendSmsSheet({required this.bookingId, this.initialPhone});

  @override
  ConsumerState<_SendSmsSheet> createState() => _SendSmsSheetState();
}

class _SendSmsSheetState extends ConsumerState<_SendSmsSheet> {
  late final TextEditingController _phoneCtrl;
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro invalide')),
      );
      return;
    }
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/bookings/${widget.bookingId}/send-ticket-sms', data: {'phone': phone});
      if (mounted) setState(() { _sent = true; _loading = false; });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          if (_sent) ...[
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 12),
            Text('Billet envoyé par SMS',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text('Le client reçoit un lien pour récupérer son billet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ),
          ] else ...[
            Text('Envoyer le billet par SMS',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text('Le client recevra un lien pour ouvrir son billet (QR).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: 16),
            PhoneInputField(controller: _phoneCtrl, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _send,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Envoyer'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
