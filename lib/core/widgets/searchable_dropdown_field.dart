import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// Dropdown avec recherche intégrée, équivalent Flutter du SearchableSelect web.
///
/// Usage :
/// ```dart
/// SearchableDropdownField<City>(
///   label: 'Ville départ',
///   hint: 'Sélectionner…',
///   value: _origin,
///   items: cities,
///   itemLabel: (c) => c.name,
///   onChanged: (c) => setState(() => _origin = c),
/// )
/// ```
class SearchableDropdownField<T> extends StatelessWidget {
  const SearchableDropdownField({
    super.key,
    required this.items,
    required this.itemLabel,
    this.itemKey,
    this.value,
    this.onChanged,
    this.label,
    this.hint = 'Sélectionner…',
    this.clearable = false,
    this.enabled = true,
    this.validator,
    this.itemSub,
  });

  final List<T>              items;
  final String Function(T)   itemLabel;
  final String Function(T)?  itemSub;
  /// Clé unique pour la comparaison (ex: id). Par défaut utilise == sur T.
  final Object Function(T)?  itemKey;
  final T?                   value;
  final ValueChanged<T?>?    onChanged;
  final String?              label;
  final String               hint;
  final bool                 clearable;
  final bool                 enabled;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator:    validator,
      initialValue: value,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
            ],
            GestureDetector(
              onTap: enabled
                  ? () => _openPicker(context, state)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: enabled ? context.inputFill : context.inputFill.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: state.hasError
                      ? Border.all(color: Colors.red.shade400)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value != null ? itemLabel(value as T) : hint,
                        style: TextStyle(
                          fontSize: 14,
                          color: value != null
                              ? context.textPrimary
                              : context.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (clearable && value != null)
                      GestureDetector(
                        onTap: () {
                          onChanged?.call(null);
                          state.didChange(null);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.close, size: 16, color: context.textMuted),
                        ),
                      ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  state.errorText!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isSelected(T item) {
    if (value == null) return false;
    if (itemKey != null) return itemKey!(item) == itemKey!(value as T);
    return item == value;
  }

  Future<void> _openPicker(BuildContext context, FormFieldState<T> state) async {
    final picked = await showModalBottomSheet<T>(
      context:            context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand:          false,
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        builder: (ctx, scroll) => _SearchPicker<T>(
          items:       items,
          itemLabel:   itemLabel,
          itemSub:     itemSub,
          isSelected:  _isSelected,
          scrollCtrl:  scroll,
          title:       label,
        ),
      ),
    );
    if (picked != null) {
      onChanged?.call(picked);
      state.didChange(picked);
    }
  }
}

// ── Picker bottom sheet ───────────────────────────────────────────────────────

class _SearchPicker<T> extends StatefulWidget {
  const _SearchPicker({
    required this.items,
    required this.itemLabel,
    required this.isSelected,
    required this.scrollCtrl,
    this.itemSub,
    this.title,
  });

  final List<T>             items;
  final String Function(T)  itemLabel;
  final String Function(T)? itemSub;
  final bool Function(T)    isSelected;
  final ScrollController    scrollCtrl;
  final String?             title;

  @override
  State<_SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<_SearchPicker<T>> {
  String _q = '';

  List<T> get _filtered => _q.isEmpty
      ? widget.items
      : widget.items
          .where((i) => widget.itemLabel(i).toLowerCase().contains(_q.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Poignée + titre ──────────────────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (widget.title != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.title!,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 12),

        // ── Recherche ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            onChanged:  (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText:   'Rechercher…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // ── Liste ────────────────────────────────────────────────────────────
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun résultat',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollCtrl,
                  itemCount:  _filtered.length,
                  itemBuilder: (_, i) {
                    final item     = _filtered[i];
                    final label    = widget.itemLabel(item);
                    final sub      = widget.itemSub?.call(item);
                    final selected = widget.isSelected(item);

                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          color:      selected ? brandOrange : null,
                        ),
                      ),
                      subtitle: sub != null
                          ? Text(sub, style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: brandOrange, size: 18)
                          : null,
                      selectedTileColor: brandOrange.withValues(alpha: 0.07),
                      selected:          selected,
                      onTap:             () => Navigator.pop(context, item),
                    );
                  },
                ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}
