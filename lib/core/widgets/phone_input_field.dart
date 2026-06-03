import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ── Pays supportés ────────────────────────────────────────────────────────────

class _Country {
  final String name;
  final String flag;
  final String dialCode;
  const _Country(this.name, this.flag, this.dialCode);
}

const _kCountries = [
  _Country('Côte d\'Ivoire', '🇨🇮', '+225'),
  _Country('Sénégal',        '🇸🇳', '+221'),
  _Country('Mali',           '🇲🇱', '+223'),
  _Country('Burkina Faso',   '🇧🇫', '+226'),
  _Country('Guinée',         '🇬🇳', '+224'),
  _Country('Togo',           '🇹🇬', '+228'),
  _Country('Bénin',          '🇧🇯', '+229'),
  _Country('Cameroun',       '🇨🇲', '+237'),
  _Country('Nigeria',        '🇳🇬', '+234'),
  _Country('Ghana',          '🇬🇭', '+233'),
  _Country('Niger',          '🇳🇪', '+227'),
  _Country('France',         '🇫🇷', '+33'),
];

// ── Widget principal ──────────────────────────────────────────────────────────

/// Champ de saisie téléphone avec sélecteur de pays.
///
/// Le [controller] (externe, optionnel) reçoit toujours le numéro international
/// complet, ex : "+2250712345678". [onChanged] reçoit la même valeur.
///
/// Usage minimal :
/// ```dart
/// PhoneInputField(controller: _phoneCtrl, onChanged: _onPhoneChanged)
/// ```
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.suffixIcon,
    this.autofocus = false,
    this.enabled   = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>?  onChanged;
  final String?  hintText;
  final String?  labelText;
  final Widget?  suffixIcon;
  final bool     autofocus;
  final bool     enabled;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late _Country _country;
  late final TextEditingController _localCtrl;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller?.text.trim() ?? '';
    final (country, local) = _parsePhone(initial);
    _country   = country;
    _localCtrl = TextEditingController(text: local);
    _localCtrl.addListener(_sync);
  }

  @override
  void dispose() {
    _localCtrl
      ..removeListener(_sync)
      ..dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Décompose un numéro international en (pays, numéro local sans indicatif).
  static (_Country, String) _parsePhone(String full) {
    if (full.isEmpty) return (_kCountries.first, '');
    for (final c in _kCountries) {
      if (full.startsWith(c.dialCode)) {
        return (c, full.substring(c.dialCode.length));
      }
    }
    // Format inconnu — on garde CI par défaut, on expose le texte brut
    return (_kCountries.first, full.startsWith('+') ? full.substring(1) : full);
  }

  void _sync() {
    final local = _localCtrl.text.trim().replaceAll(' ', '');
    final full  = local.isEmpty ? '' : '${_country.dialCode}$local';
    widget.controller?.value = TextEditingValue(
      text:      full,
      selection: TextSelection.collapsed(offset: full.length),
    );
    widget.onChanged?.call(full);
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<_Country>(
      context:    context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand:          false,
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        builder: (ctx, scroll) => _CountryPicker(
          selected:  _country,
          scrollCtrl: scroll,
        ),
      ),
    );
    if (picked != null && picked.dialCode != _country.dialCode) {
      setState(() => _country = picked);
      _sync();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bouton indicatif ─────────────────────────────────────────────────
        GestureDetector(
          onTap: widget.enabled ? _pickCountry : null,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color:        context.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
                Text(
                  _country.dialCode,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      context.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 18, color: context.textMuted),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── Champ numéro local ───────────────────────────────────────────────
        Expanded(
          child: TextField(
            controller:  _localCtrl,
            autofocus:   widget.autofocus,
            enabled:     widget.enabled,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
            ],
            decoration: InputDecoration(
              hintText:   widget.hintText  ?? '07 XX XX XX XX',
              labelText:  widget.labelText,
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sélecteur de pays (bottom sheet) ─────────────────────────────────────────

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({required this.selected, required this.scrollCtrl});
  final _Country             selected;
  final ScrollController     scrollCtrl;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _q = '';

  List<_Country> get _filtered => _q.isEmpty
      ? _kCountries
      : _kCountries.where((c) =>
          c.name.toLowerCase().contains(_q.toLowerCase()) ||
          c.dialCode.contains(_q)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Poignée ──────────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText:   'Rechercher un pays…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            controller:  widget.scrollCtrl,
            itemCount:   _filtered.length,
            itemBuilder: (_, i) {
              final c        = _filtered[i];
              final selected = c.dialCode == widget.selected.dialCode;
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                title: Text(c.name, style: const TextStyle(fontSize: 14)),
                trailing: Text(
                  c.dialCode,
                  style: TextStyle(
                    fontSize:   13,
                    color:      selected ? brandOrange : context.textMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                selected:          selected,
                selectedTileColor: brandOrange.withValues(alpha: 0.08),
                onTap:             () => Navigator.pop(context, c),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}
