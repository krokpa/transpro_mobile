import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shimmer.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Key is "parcelId" or "code:TRACKING_CODE" for public access.
final _existingRequestProvider = FutureProvider.autoDispose
    .family<DeliveryRequest?, String>((ref, key) async {
  try {
    final dio = ref.read(dioProvider);
    final url = key.startsWith('code:')
        ? '/parcels/track/${key.substring(5)}/delivery-request'
        : '/parcels/$key/delivery-request';
    final res = await dio.get(url);
    final data = extractData(res.data);
    if (data == null) return null;
    return DeliveryRequest.fromJson(data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// ── Status config ─────────────────────────────────────────────────────────────

const _drStatusCfg = {
  'PENDING':   (label: 'En attente',  color: Color(0xFF6B7280)),
  'ASSIGNED':  (label: 'Assigné',     color: Color(0xFF3B82F6)),
  'EN_ROUTE':  (label: 'En chemin',   color: Color(0xFFEA580C)),
  'DELIVERED': (label: 'Livré ✓',     color: Color(0xFF16A34A)),
  'FAILED':    (label: 'Échec',       color: Color(0xFFEF4444)),
  'CANCELLED': (label: 'Annulé',      color: Color(0xFF6B7280)),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class DeliveryRequestScreen extends ConsumerStatefulWidget {
  /// ID Prisma du colis — null si accès public par code de suivi.
  final String? parcelId;
  final String trackingCode;

  const DeliveryRequestScreen({
    super.key,
    this.parcelId,
    required this.trackingCode,
  });

  @override
  ConsumerState<DeliveryRequestScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryRequestScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();

  bool _loading = false;
  bool _cancelling = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _districtCtrl.dispose();
    _landmarkCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _prefillFromUser() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_nameCtrl.text.isEmpty) _nameCtrl.text = user.fullName;
    if (_phoneCtrl.text.isEmpty && user.phone != null) _phoneCtrl.text = user.phone!;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final url = widget.parcelId != null
          ? '/parcels/${widget.parcelId}/delivery-request'
          : '/parcels/track/${widget.trackingCode}/delivery-request';
      await dio.post(url, data: {
        'address':      _addressCtrl.text.trim(),
        'district':     _districtCtrl.text.trim().isNotEmpty ? _districtCtrl.text.trim() : null,
        'landmark':     _landmarkCtrl.text.trim().isNotEmpty ? _landmarkCtrl.text.trim() : null,
        'contactName':  _nameCtrl.text.trim(),
        'contactPhone': _phoneCtrl.text.trim(),
      });
      if (mounted) {
        ref.invalidate(_existingRequestProvider(_providerKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée ! L\'agence vous contactera prochainement.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
      );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(DeliveryRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text('Cette action annulera votre demande de livraison à domicile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la demande', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final dio = ref.read(dioProvider);
      final url = widget.parcelId != null
          ? '/parcels/${widget.parcelId}/delivery-request'
          : '/parcels/track/${widget.trackingCode}/delivery-request';
      await dio.delete(url);
      if (mounted) {
        ref.invalidate(_existingRequestProvider(_providerKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande annulée'), backgroundColor: Colors.orange),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
      );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  String get _providerKey =>
      widget.parcelId != null ? widget.parcelId! : 'code:${widget.trackingCode}';

  @override
  Widget build(BuildContext context) {
    final existingAsync = ref.watch(_existingRequestProvider(_providerKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livraison à domicile'),
        centerTitle: false,
      ),
      body: existingAsync.when(
        loading: () => AppShimmer.listTiles(count: 3),
        error: (_, _) => _buildForm(),
        data: (existing) {
          if (existing != null && !['CANCELLED', 'FAILED'].contains(existing.status)) {
            return _buildExisting(existing);
          }
          return _buildForm();
        },
      ),
    );
  }

  // ── Existing delivery request view ────────────────────────────────────────

  Widget _buildExisting(DeliveryRequest req) {
    final cfg = _drStatusCfg[req.status] ?? _drStatusCfg['PENDING']!;
    final canCancel = ['PENDING', 'ASSIGNED'].contains(req.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: cfg.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(req.status), color: cfg.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  cfg.label,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cfg.color),
                ),
                Text(
                  _statusMessage(req.status),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ])),
            ]),
          ),

          const SizedBox(height: 20),

          // Delivery details
          _InfoCard(title: 'Adresse de livraison', children: [
            _Row(label: 'Adresse', value: req.address),
            if (req.district != null) _Row(label: 'Quartier', value: req.district!),
            if (req.landmark != null) _Row(label: 'Point de repère', value: req.landmark!),
          ]),
          const SizedBox(height: 12),
          _InfoCard(title: 'Contact', children: [
            _Row(label: 'Nom', value: req.contactName),
            _Row(label: 'Téléphone', value: req.contactPhone),
          ]),

          if (req.deliveryFee != null) ...[
            const SizedBox(height: 12),
            _InfoCard(title: 'Frais de livraison', children: [
              _Row(
                label: 'Montant',
                value: '${req.deliveryFee!.toStringAsFixed(0)} FCFA',
                highlight: true,
              ),
              _Row(
                label: 'Statut',
                value: req.isPaid ? 'Payé ✓' : 'À payer à la livraison',
              ),
            ]),
          ],

          if (req.failReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  req.failReason!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                )),
              ]),
            ),
          ],

          if (canCancel) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelling ? null : () => _cancel(req),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _cancelling
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                    : const Text('Annuler la demande', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Request form ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    // Pre-fill on first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromUser());

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandOrange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandOrange.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.home_outlined, color: brandOrange, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text(
                  'Renseignez l\'adresse où vous souhaitez recevoir votre colis. '
                  'Un livreur de l\'agence vous contactera.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                )),
              ]),
            ),

            const SizedBox(height: 24),

            // Address section
            _SectionLabel('Adresse de livraison'),
            const SizedBox(height: 10),
            _Field(
              controller: _addressCtrl,
              label: 'Adresse complète *',
              hint: 'Ex: Rue des Jardins, Côté marché Gouro',
              icon: Icons.location_on_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _districtCtrl,
              label: 'Quartier / Commune',
              hint: 'Ex: Abobo, Yopougon, Cocody...',
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _landmarkCtrl,
              label: 'Point de repère (optionnel)',
              hint: 'Ex: En face de l\'église, derrière la pharmacie',
              icon: Icons.place_outlined,
            ),

            const SizedBox(height: 20),

            // Contact section
            _SectionLabel('Contact pour la livraison'),
            const SizedBox(height: 10),
            _Field(
              controller: _nameCtrl,
              label: 'Nom du destinataire *',
              hint: 'Nom complet',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _phoneCtrl,
              label: 'Téléphone *',
              hint: '+225 07 XX XX XX XX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer la demande',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _statusIcon(String status) => switch (status) {
  'PENDING'   => Icons.access_time_rounded,
  'ASSIGNED'  => Icons.person_rounded,
  'EN_ROUTE'  => Icons.local_shipping_rounded,
  'DELIVERED' => Icons.check_circle_rounded,
  'FAILED'    => Icons.error_outline,
  'CANCELLED' => Icons.cancel_outlined,
  _           => Icons.help_outline,
};

String _statusMessage(String status) => switch (status) {
  'PENDING'   => 'En attente de traitement par l\'agence',
  'ASSIGNED'  => 'Un livreur a été assigné à votre colis',
  'EN_ROUTE'  => 'Votre livreur est en chemin !',
  'DELIVERED' => 'Votre colis a été livré avec succès',
  'FAILED'    => 'La livraison a échoué — contactez l\'agence',
  'CANCELLED' => 'Demande annulée',
  _           => '',
};

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
      const SizedBox(height: 10),
      ...children,
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Row({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 110,
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ),
      Expanded(child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: highlight ? brandOrange : Color(0xFF0F172A),
        ),
      )),
    ]),
  );
}
