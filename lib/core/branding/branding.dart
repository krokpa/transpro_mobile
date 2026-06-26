import 'package:flutter/material.dart';
import '../settings/settings_cache.dart';

/// Couleur de marque par défaut (orange historique) — sert de repli si ni l'env
/// ni l'API ne fournissent de couleur valide.
const kBrandColorFallback = Color(0xFFF97316);

// ── Défauts build-time (white-label) ───────────────────────────────────────────
// Surchargés à la compilation via --dart-define, ex. :
//   flutter build apk --dart-define=APP_NAME=Acme \
//     --dart-define=BRAND_COLOR=#2563EB --dart-define=APP_LOGO=https://…/logo.png
const _envAppName = String.fromEnvironment('APP_NAME', defaultValue: 'TransPro CI');
const _envTagline = String.fromEnvironment('APP_TAGLINE', defaultValue: 'Voyagez malin');
const _envColorHex = String.fromEnvironment('BRAND_COLOR', defaultValue: '#F97316');
const _envLogo = String.fromEnvironment('APP_LOGO', defaultValue: '');

/// Identité de marque résolue côté app (défauts build-time → cache → API).
@immutable
class Branding {
  final String appName;
  final String tagline;
  final Color primaryColor;
  final String? logoUrl;

  const Branding({
    required this.appName,
    required this.tagline,
    required this.primaryColor,
    this.logoUrl,
  });

  Branding copyWith({
    String? appName,
    String? tagline,
    Color? primaryColor,
    String? logoUrl,
  }) =>
      Branding(
        appName: appName ?? this.appName,
        tagline: tagline ?? this.tagline,
        primaryColor: primaryColor ?? this.primaryColor,
        logoUrl: logoUrl ?? this.logoUrl,
      );
}

/// Convertit un hex (`#RRGGBB` ou `RRGGBB`) en [Color]. Repli sur [fallback].
Color brandingColorFromHex(String? hex, {Color fallback = kBrandColorFallback}) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String? _nonEmpty(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : null;

/// Marque initiale au démarrage : dernière valeur connue (cache hors-ligne)
/// sinon les défauts build-time. Garantit un 1er paint correct sans réseau.
Branding brandingDefaults() {
  final logo = _nonEmpty(SettingsCache.brandLogo) ?? _nonEmpty(_envLogo);
  return Branding(
    appName: _nonEmpty(SettingsCache.brandName) ?? _envAppName,
    tagline: _nonEmpty(SettingsCache.brandTagline) ?? _envTagline,
    primaryColor:
        brandingColorFromHex(_nonEmpty(SettingsCache.brandColor) ?? _envColorHex),
    logoUrl: logo,
  );
}
