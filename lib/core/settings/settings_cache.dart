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

  static String? get brandName            => _read('brand_name');
  static String? get brandTagline         => _read('brand_tagline');
  static String? get brandColor           => _read('brand_color');
  static String? get brandSecondaryColor  => _read('brand_secondary');
  static String? get brandTertiaryColor   => _read('brand_tertiary');
  static String? get brandPassengerColor  => _read('brand_passenger');
  static String? get brandAgentColor      => _read('brand_agent');
  static String? get brandOwnerColor      => _read('brand_owner');
  static String? get brandDriverColor     => _read('brand_driver');
  static String? get brandLogo            => _read('brand_logo');

  /// Persiste les champs fournis (les `null` sont ignorés).
  static Future<void> setBrand({
    String? name,
    String? tagline,
    String? colorHex,
    String? secondaryHex,
    String? tertiaryHex,
    String? passengerHex,
    String? agentHex,
    String? ownerHex,
    String? driverHex,
    String? logo,
  }) async {
    if (name != null)         await _box.put('brand_name', name);
    if (tagline != null)      await _box.put('brand_tagline', tagline);
    if (colorHex != null)     await _box.put('brand_color', colorHex);
    if (secondaryHex != null) await _box.put('brand_secondary', secondaryHex);
    if (tertiaryHex != null)  await _box.put('brand_tertiary', tertiaryHex);
    if (passengerHex != null) await _box.put('brand_passenger', passengerHex);
    if (agentHex != null)     await _box.put('brand_agent', agentHex);
    if (ownerHex != null)     await _box.put('brand_owner', ownerHex);
    if (driverHex != null)    await _box.put('brand_driver', driverHex);
    if (logo != null)         await _box.put('brand_logo', logo);
  }
}
