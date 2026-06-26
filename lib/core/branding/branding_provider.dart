import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../settings/settings_cache.dart';
import 'branding.dart';

/// Marque de la plateforme : défauts build-time / cache au démarrage, puis
/// override runtime depuis `GET /platform-settings` (endpoint public). Source
/// white-label unique partagée avec le front web et le backend.
class BrandingNotifier extends Notifier<Branding> {
  @override
  Branding build() {
    // Récupération en arrière-plan ; l'UI démarre sur les valeurs par défaut.
    _fetch();
    return brandingDefaults();
  }

  /// Re-synchronise la marque depuis l'API (ex. après changement admin).
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/platform-settings');
      final data = extractData(res.data);
      if (data is! Map) return;

      final appName = (data['appName'] as String?)?.trim();
      final tagline = (data['tagline'] as String?)?.trim();
      final colorHex = (data['primaryColor'] as String?)?.trim();
      final logoUrl = (data['logoUrl'] as String?)?.trim();

      state = Branding(
        appName: appName != null && appName.isNotEmpty ? appName : state.appName,
        tagline: tagline != null && tagline.isNotEmpty ? tagline : state.tagline,
        primaryColor: colorHex != null && colorHex.isNotEmpty
            ? brandingColorFromHex(colorHex)
            : state.primaryColor,
        logoUrl: logoUrl != null && logoUrl.isNotEmpty ? logoUrl : state.logoUrl,
      );

      // Persiste pour un 1er paint correct hors-ligne au prochain démarrage.
      await SettingsCache.setBrand(
        name: state.appName,
        tagline: state.tagline,
        colorHex: colorHex,
        logo: state.logoUrl,
      );
    } catch (_) {
      // Réseau indisponible / settings absents : on conserve les défauts.
    }
  }
}

final brandingProvider =
    NotifierProvider<BrandingNotifier, Branding>(BrandingNotifier.new);
