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

  // ── Onboarding ─────────────────────────────────────────────────────────────

  static bool get onboardingDone => _box.get('onboarding_done') == '1';

  static Future<void> markOnboardingDone() => _box.put('onboarding_done', '1');
}
