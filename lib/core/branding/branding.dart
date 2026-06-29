import 'package:flutter/material.dart';
import '../settings/settings_cache.dart';

/// Couleur de marque par défaut (orange historique) — repli ultime.
const kBrandColorFallback = Color(0xFFF97316);

// Défauts des couleurs secondaire/tertiaire et des 4 espaces (valeurs
// historiques). Surchargeables par l'admin (/platform-settings) ou au build.
const _kSecondaryDefault = Color(0xFF0EA5E9); // sky-500
const _kTertiaryDefault  = Color(0xFF6366F1); // indigo-500
const _kPassengerDefault = Color(0xFF0EA5E9); // sky
const _kAgentDefault     = Color(0xFF10B981); // emerald
const _kOwnerDefault     = Color(0xFF6366F1); // indigo
const _kDriverDefault    = Color(0xFFF97316); // orange

// ── Défauts build-time (white-label) — surchargeables via --dart-define ────────
const _envAppName   = String.fromEnvironment('APP_NAME', defaultValue: 'TransPro CI');
const _envTagline   = String.fromEnvironment('APP_TAGLINE', defaultValue: 'Voyagez malin');
const _envColorHex  = String.fromEnvironment('BRAND_COLOR', defaultValue: '#F97316');
const _envSecondary = String.fromEnvironment('BRAND_SECONDARY', defaultValue: '');
const _envTertiary  = String.fromEnvironment('BRAND_TERTIARY', defaultValue: '');
const _envLogo      = String.fromEnvironment('APP_LOGO', defaultValue: '');

/// Identité de marque résolue côté app (défauts build-time → cache → API).
/// 7 couleurs : 3 de marque (primaire/secondaire/tertiaire) + 4 d'espace.
@immutable
class Branding {
  final String appName;
  final String tagline;
  final String? logoUrl;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color passengerColor;
  final Color agentColor;
  final Color ownerColor;
  final Color driverColor;

  const Branding({
    required this.appName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.passengerColor,
    required this.agentColor,
    required this.ownerColor,
    required this.driverColor,
    this.logoUrl,
  });

  Branding copyWith({
    String? appName,
    String? tagline,
    String? logoUrl,
    Color? primaryColor,
    Color? secondaryColor,
    Color? tertiaryColor,
    Color? passengerColor,
    Color? agentColor,
    Color? ownerColor,
    Color? driverColor,
  }) =>
      Branding(
        appName: appName ?? this.appName,
        tagline: tagline ?? this.tagline,
        logoUrl: logoUrl ?? this.logoUrl,
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        tertiaryColor: tertiaryColor ?? this.tertiaryColor,
        passengerColor: passengerColor ?? this.passengerColor,
        agentColor: agentColor ?? this.agentColor,
        ownerColor: ownerColor ?? this.ownerColor,
        driverColor: driverColor ?? this.driverColor,
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
  Color col(String? cached, String? env, Color fallback) =>
      brandingColorFromHex(_nonEmpty(cached) ?? _nonEmpty(env), fallback: fallback);
  return Branding(
    appName: _nonEmpty(SettingsCache.brandName) ?? _envAppName,
    tagline: _nonEmpty(SettingsCache.brandTagline) ?? _envTagline,
    logoUrl: logo,
    primaryColor:   col(SettingsCache.brandColor,          _envColorHex,  kBrandColorFallback),
    secondaryColor: col(SettingsCache.brandSecondaryColor, _envSecondary, _kSecondaryDefault),
    tertiaryColor:  col(SettingsCache.brandTertiaryColor,  _envTertiary,  _kTertiaryDefault),
    passengerColor: col(SettingsCache.brandPassengerColor, null, _kPassengerDefault),
    agentColor:     col(SettingsCache.brandAgentColor,     null, _kAgentDefault),
    ownerColor:     col(SettingsCache.brandOwnerColor,     null, _kOwnerDefault),
    driverColor:    col(SettingsCache.brandDriverColor,    null, _kDriverDefault),
  );
}
