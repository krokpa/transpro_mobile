import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _LogoStyle { standard, tile, onDark }

/// Logo d'une compagnie de transport.
///
/// Affiche le logo si [logo] est fourni, sinon une pastille avec une icône de
/// bus. Le logo peut être une URL réseau (`http(s)://…`) ou une data URI
/// base64 (`data:image/…;base64,…`) — c'est sous cette forme que le backend
/// stocke les logos. Utilisé partout où une compagnie est affichée.
///
/// Trois variantes :
/// - [CompanyLogo] : style standard (listes, cartes de voyage, transactions…).
/// - [CompanyLogo.tile] : pastille teintée orange (grilles compagnies, favoris).
/// - [CompanyLogo.onDark] : version claire pour fond sombre/dégradé (en-têtes).
class CompanyLogo extends StatelessWidget {
  final String? logo;
  final double size;
  final _LogoStyle _style;

  const CompanyLogo({super.key, this.logo, this.size = 32})
      : _style = _LogoStyle.standard;

  const CompanyLogo.tile({super.key, this.logo, this.size = 52})
      : _style = _LogoStyle.tile;

  const CompanyLogo.onDark({super.key, this.logo, this.size = 64})
      : _style = _LogoStyle.onDark;

  double get _radiusFactor => _style == _LogoStyle.standard ? 0.25 : 0.2;
  double get _iconFactor => _style == _LogoStyle.standard ? 0.55 : 0.5;
  IconData get _icon => _style == _LogoStyle.standard
      ? Icons.directions_bus_filled
      : Icons.directions_bus_rounded;

  /// Décode une data URI base64 en octets, ou null si [logo] n'en est pas une.
  Uint8List? _decodeDataUri() {
    final src = logo;
    if (src == null || !src.startsWith('data:')) return null;
    final comma = src.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(src.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = logo;
    if (src != null && src.isNotEmpty) {
      final bytes = _decodeDataUri();
      final Widget image = bytes != null
          ? Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(context),
            )
          : Image.network(
              src,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(context),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * _radiusFactor),
        child: Container(
          width: size,
          height: size,
          color: Colors.white,
          padding: EdgeInsets.all(size * 0.08),
          child: image,
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (_style) {
      case _LogoStyle.standard:
        bg = context.tagBg;
        fg = brandOrange;
      case _LogoStyle.tile:
        bg = brandOrange.withValues(alpha: 0.1);
        fg = brandOrange;
      case _LogoStyle.onDark:
        bg = Colors.white.withValues(alpha: 0.15);
        fg = Colors.white70;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * _radiusFactor),
      ),
      child: Icon(_icon, color: fg, size: size * _iconFactor),
    );
  }
}
