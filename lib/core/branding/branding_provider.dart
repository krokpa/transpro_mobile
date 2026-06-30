import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../settings/settings_cache.dart';
import '../theme/app_theme.dart';
import '../theme/space_theme.dart';
import 'branding.dart';

/// Marque de la plateforme : défauts build-time / cache au démarrage, puis
/// override runtime depuis `GET /platform-settings` (endpoint public). Source
/// white-label unique partagée avec le front web et le backend.
/// Gère 7 couleurs : primaire/secondaire/tertiaire + 4 espaces.
class BrandingNotifier extends Notifier<Branding> {
  @override
  Branding build() {
    final initial = brandingDefaults();
    _applySpaces(initial); // les palettes d'espace reflètent le cache/build dès le départ
    _fetch();
    return initial;
  }

  /// Re-synchronise la marque depuis l'API (ex. après changement admin).
  Future<void> refresh() => _fetch();

  /// Pousse les couleurs résolues dans les globals runtime du thème
  /// (accent `brandOrange` + palettes d'espace), lus par toute l'app.
  void _applySpaces(Branding b) {
    applyBrandPrimary(b.primaryColor);
    applyBrandSpaces(
      passenger: b.passengerColor,
      agent: b.agentColor,
      owner: b.ownerColor,
      driver: b.driverColor,
    );
  }

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/platform-settings');
      final data = extractData(res.data);
      if (data is! Map) return;

      String? str(String k) {
        final v = (data[k] as String?)?.trim();
        return (v != null && v.isNotEmpty) ? v : null;
      }

      Color col(String k, Color current) {
        final hex = str(k);
        return hex != null ? brandingColorFromHex(hex, fallback: current) : current;
      }

      state = state.copyWith(
        appName: str('appName'),
        tagline: str('tagline'),
        logoUrl: str('logoUrl'),
        primaryColor:   col('primaryColor',   state.primaryColor),
        secondaryColor: col('secondaryColor', state.secondaryColor),
        tertiaryColor:  col('tertiaryColor',  state.tertiaryColor),
        passengerColor: col('passengerColor', state.passengerColor),
        agentColor:     col('agentColor',     state.agentColor),
        ownerColor:     col('ownerColor',     state.ownerColor),
        driverColor:    col('driverColor',    state.driverColor),
      );

      _applySpaces(state);

      // Persiste pour un 1er paint correct hors-ligne au prochain démarrage.
      await SettingsCache.setBrand(
        name: state.appName,
        tagline: state.tagline,
        logo: state.logoUrl,
        colorHex:     str('primaryColor'),
        secondaryHex: str('secondaryColor'),
        tertiaryHex:  str('tertiaryColor'),
        passengerHex: str('passengerColor'),
        agentHex:     str('agentColor'),
        ownerHex:     str('ownerColor'),
        driverHex:    str('driverColor'),
      );
    } catch (_) {
      // Réseau indisponible / settings absents : on conserve les défauts.
    }
  }
}

final brandingProvider =
    NotifierProvider<BrandingNotifier, Branding>(BrandingNotifier.new);
