import 'package:hive_flutter/hive_flutter.dart';

class SettingsCache {
  static const _boxName = 'app_settings';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  // ── Theme ──────────────────────────────────────────────────────────────────

  static String get themeMode => _box.get('theme_mode') ?? 'system';

  static Future<void> setThemeMode(String mode) => _box.put('theme_mode', mode);

  // ── Locale ─────────────────────────────────────────────────────────────────

  static String? get locale {
    final value = _box.get('locale');
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> setLocale(String languageCode) =>
      _box.put('locale', languageCode);

  // ── Onboarding passager ────────────────────────────────────────────────────

  static bool get onboardingDone => _box.get('onboarding_done') == '1';

  static Future<void> markOnboardingDone() => _box.put('onboarding_done', '1');

  // ── Walkthrough par rôle (driver / owner / agent) ──────────────────────────

  static bool walkthroughDone(String role) =>
      _box.get('walkthrough_done_$role') == '1';

  static Future<void> markWalkthroughDone(String role) =>
      _box.put('walkthrough_done_$role', '1');

  // ── Marque (white-label) ─────────────────────────────────────────────────────
  // Dernière marque connue, persistée pour un 1er paint correct hors-ligne.

  static String? _read(String key) {
    final v = _box.get(key);
    return v == null || v.isEmpty ? null : v;
  }

  static String? get brandName    => _read('brand_name');
  static String? get brandTagline => _read('brand_tagline');
  static String? get brandColor   => _read('brand_color');
  static String? get brandLogo    => _read('brand_logo');

  /// Persiste les champs fournis (les `null` sont ignorés).
  static Future<void> setBrand({
    String? name,
    String? tagline,
    String? colorHex,
    String? logo,
  }) async {
    if (name != null)     await _box.put('brand_name', name);
    if (tagline != null)  await _box.put('brand_tagline', tagline);
    if (colorHex != null) await _box.put('brand_color', colorHex);
    if (logo != null)     await _box.put('brand_logo', logo);
  }
}
