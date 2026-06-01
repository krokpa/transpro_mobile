import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _citiesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/cities');
  return (extractData(res.data) as List).map((e) => City.fromJson(e)).toList();
});

final _availableTripsProvider = FutureProvider.autoDispose
    .family<List<Trip>, String>((ref, destCity) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/trips/search', queryParameters: {
    'origin': '',
    'destination': destCity,
    'departureDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'passengers': 0,
  });
  return (extractData(res.data) as List).map((e) => Trip.fromJson(e)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SendParcelScreen extends ConsumerStatefulWidget {
  const SendParcelScreen({super.key});
  @override
  ConsumerState<SendParcelScreen> createState() => _State();
}

class _State extends ConsumerState<SendParcelScreen> {
  // Form state
  Trip?   _trip;
  City?   _destCity;
  String  _recipientId    = '';
  String  _recipientName  = '';
  String  _recipientPhone = '';
  String  _description    = '';
  double? _weightKg;
  bool    _fragile        = false;
  bool    _isPaid         = false;
  String  _payMethod      = 'CASH';
  int?    _estimatedFee;

  bool _loading       = false;
  bool _feeLoading    = false;
  String? _error;

  // Recipient phone lookup
  Map<String, dynamic>? _recipientMatch;
  Timer? _lookupTimer;

  final _recipNameCtrl  = TextEditingController();
  final _recipPhoneCtrl = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _weightCtrl     = TextEditingController();

  void _onRecipientPhoneChanged(String phone) {
    _recipientPhone = phone;
    _recipientMatch = null;
    _recipientId    = '';
    _lookupTimer?.cancel();
    if (phone.trim().length < 8) return;
    _lookupTimer = Timer(const Duration(milliseconds: 600), () async {
      final dio = ref.read(dioProvider);
      final result = await lookupUserByPhone(dio, phone.trim());
      if (!mounted) return;
      setState(() {
        _recipientMatch = result;
        if (result != null) {
          _recipientId = result['id'] as String? ?? '';
          if (_recipNameCtrl.text.isEmpty) {
            final name = '${result['firstName'] ?? ''} ${result['lastName'] ?? ''}'.trim();
            _recipNameCtrl.text = name;
            _recipientName = name;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _recipNameCtrl.dispose();
    _recipPhoneCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── Fee estimation ────────────────────────────────────────────────────────

  Future<void> _estimateFee() async {
    if (_trip == null || _weightKg == null || _weightKg! <= 0) return;
    setState(() => _feeLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/parcels/estimate-fee', queryParameters: {
        'tripId': _trip!.id,
        'weightKg': _weightKg,
      });
      final data = extractData(res.data);
      setState(() => _estimatedFee = data['fee'] as int?);
    } catch (_) {}
    finally { if (mounted) setState(() => _feeLoading = false); }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_trip == null || _recipientName.isEmpty || _recipientPhone.isEmpty ||
        _description.isEmpty || _weightKg == null) {
      setState(() => _error = 'Veuillez remplir tous les champs obligatoires');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/parcels/my', data: {
        'tripId':         _trip!.id,
        if (_recipientId.isNotEmpty) 'recipientId': _recipientId,
        'recipientName':  _recipientName,
        'recipientPhone': _recipientPhone,
        'deliveryCity':   _destCity?.name ?? _trip!.destinationCity,
        'description':    _description,
        'weightKg':       _weightKg,
        'fragile':        _fragile,
        'fee':            _estimatedFee,
        'isPaid':         _isPaid,
        if (_isPaid) 'paymentMethod': _payMethod,
      });
      final data = extractData(res.data);
      final code = data['trackingCode'] as String?;

      if (mounted) {
        // Show success + navigate to tracking
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SuccessDialog(trackingCode: code ?? ''),
        );
        if (mounted) context.pushReplacement('/passenger/parcels');
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user       = ref.read(authProvider).user;
    final citiesAsync = ref.watch(_citiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envoyer un colis'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Expéditeur (auto-rempli) ────────────────────────────────────
          _SectionTitle('Expéditeur', subtitle: 'Votre profil est utilisé automatiquement'),
          _InfoTile(
            icon: Icons.person_outline,
            title: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
            subtitle: user?.phone ?? '',
          ),
          const SizedBox(height: 20),

          // ── Destination & voyage ────────────────────────────────────────
          _SectionTitle('Destination'),
          const SizedBox(height: 10),

          // City picker
          _PickerButton(
            icon: Icons.location_on_outlined,
            label: _destCity?.name ?? 'Ville de destination',
            onTap: () async {
              final cities = citiesAsync.value ?? [];
              final picked = await showModalBottomSheet<City>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _CitySheet(cities: cities, title: 'Destination'),
              );
              if (picked != null) setState(() { _destCity = picked; _trip = null; });
            },
          ),

          // Trip picker (visible once city is selected)
          if (_destCity != null) ...[
            const SizedBox(height: 10),
            _TripPicker(
              destCity: _destCity!.name,
              selected: _trip,
              onSelected: (t) {
                setState(() { _trip = t; _estimatedFee = null; });
                _estimateFee();
              },
            ),
          ],
          const SizedBox(height: 20),

          // ── Destinataire ────────────────────────────────────────────────
          _SectionTitle('Destinataire'),
          const SizedBox(height: 10),
          _Field(
            controller: _recipPhoneCtrl,
            label: 'Téléphone *',
            hint: '+225 05 XX XX XX XX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onChanged: (v) {
              setState(() {});
              _onRecipientPhoneChanged(v);
            },
          ),
          if (_recipientMatch != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Passager inscrit : ${_recipientMatch!['firstName']} ${_recipientMatch!['lastName']}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          _Field(
            controller: _recipNameCtrl,
            label: 'Nom complet *',
            hint: 'Traoré Fatou',
            icon: Icons.person_outline,
            onChanged: (v) => _recipientName = v,
          ),
          const SizedBox(height: 20),

          // ── Colis ───────────────────────────────────────────────────────
          _SectionTitle('Description du colis'),
          const SizedBox(height: 10),
          _Field(
            controller: _descCtrl,
            label: 'Description *',
            hint: 'Vêtements, médicaments, documents...',
            icon: Icons.inventory_2_outlined,
            onChanged: (v) => _description = v,
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _weightCtrl,
            label: 'Poids (kg) *',
            hint: '2.5',
            icon: Icons.scale_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              setState(() => _weightKg = double.tryParse(v));
            },
            onEditingComplete: _estimateFee,
          ),
          const SizedBox(height: 12),

          // Fragile switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.divider),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Colis fragile',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Manipulation avec précaution',
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _fragile,
                  activeThumbColor: brandOrange,
                  onChanged: (v) => setState(() => _fragile = v),
                ),
              ],
            ),
          ),

          // Fee estimate
          if (_feeLoading || _estimatedFee != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined, color: brandOrange, size: 18),
                  const SizedBox(width: 10),
                  _feeLoading
                      ? Text(
                          'Calcul des frais…',
                          style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                        )
                      : Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Frais d\'envoi estimés',
                                style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                              ),
                              Text(
                                NumberFormat('#,### FCFA', 'fr_FR').format(_estimatedFee),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Paiement ─────────────────────────────────────────────────────
          _SectionTitle('Paiement'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: context.textMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payer au guichet',
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                ),
                Switch(
                  value: _isPaid,
                  activeThumbColor: brandOrange,
                  onChanged: (v) => setState(() => _isPaid = v),
                ),
              ],
            ),
          ),
          if (_isPaid) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _payMethod,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.credit_card_outlined),
                labelText: 'Moyen de paiement',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH',         child: Text('Espèces')),
                DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money')),
                DropdownMenuItem(value: 'MTN_MOMO',     child: Text('MTN MoMo')),
                DropdownMenuItem(value: 'WAVE',         child: Text('Wave')),
              ],
              onChanged: (v) => setState(() => _payMethod = v ?? 'CASH'),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Submit
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Envoyer le colis',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Success dialog ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final String trackingCode;
  const _SuccessDialog({required this.trackingCode});

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    contentPadding: const EdgeInsets.all(28),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFF0FDF4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Colis enregistré !',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre colis a été enregistré avec succès. Vous recevrez des notifications à chaque étape.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Column(
            children: [
              const Text(
                'Code de suivi',
                style: TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
              ),
              Text(
                trackingCode,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEA580C),
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Voir mes colis'),
          ),
        ),
      ],
    ),
  );
}

// ── Trip picker ───────────────────────────────────────────────────────────────

class _TripPicker extends ConsumerWidget {
  final String destCity;
  final Trip? selected;
  final ValueChanged<Trip> onSelected;
  const _TripPicker({required this.destCity, this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_availableTripsProvider(destCity));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text('Impossible de charger les voyages', style: TextStyle(color: Colors.red.shade400)),
      data: (trips) {
        if (trips.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Aucun voyage disponible vers $destCity aujourd\'hui',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voyage *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            ...trips.map((t) {
              final isSel = selected?.id == t.id;
              return GestureDetector(
                onTap: () => onSelected(t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel ? brandOrange.withValues(alpha: 0.08) : context.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? brandOrange : context.divider,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.originCity} → ${t.destinationCity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSel ? brandOrange : context.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat("d MMM, HH'h'mm", 'fr_FR').format(t.departureAt.toLocal()),
                              style: TextStyle(fontSize: 12, color: context.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (t.tenantName != null)
                        Text(
                          t.tenantName!,
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                      if (isSel)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle, color: brandOrange, size: 18),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── City sheet ────────────────────────────────────────────────────────────────

class _CitySheet extends StatefulWidget {
  final List<City> cities;
  final String title;
  const _CitySheet({required this.cities, required this.title});
  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.cities.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Rechercher...', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: filtered.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (_, i) => ListTile(
                leading: Icon(Icons.location_city_outlined, color: brandOrange, size: 20),
                title: Text(filtered[i].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () => Navigator.pop(context, filtered[i]),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle(this.title, {this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      if (subtitle != null)
        Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.divider),
    ),
    child: Row(
      children: [
        Icon(icon, color: context.textMuted, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
      ],
    ),
  );
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: context.textSecondary))),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.textMuted),
        ],
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final VoidCallback? onEditingComplete;
  const _Field({
    required this.controller, required this.label, required this.hint,
    required this.icon, this.keyboardType = TextInputType.text,
    required this.onChanged, this.onEditingComplete,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    onChanged: onChanged,
    onEditingComplete: onEditingComplete,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
