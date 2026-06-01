import 'package:hive_flutter/hive_flutter.dart';
import 'campaign_config.dart';

class NotifPrefsCache {
  static const _boxName = 'notif_prefs';

  static Future<void> init() async => Hive.openBox<String>(_boxName);

  static Box<String> get _box => Hive.box<String>(_boxName);

  // ── User-level per-campaign toggles ──────────────────────────────────────────
  // Defaults to true (enabled) unless explicitly set to '0'

  static bool isCampaignEnabled(String key) =>
      _box.get('campaign_$key') != '0';

  static Future<void> setCampaignEnabled(String key, bool enabled) =>
      _box.put('campaign_$key', enabled ? '1' : '0');

  // ── Activity tracking (re-engagement) ────────────────────────────────────────

  static DateTime get lastActiveAt {
    final s = _box.get('last_active');
    return (s != null ? DateTime.tryParse(s) : null) ?? DateTime.now();
  }

  static Future<void> markActive() =>
      _box.put('last_active', DateTime.now().toIso8601String());

  // ── Per-tenant campaign config (JSON) ─────────────────────────────────────────

  static String _configKey(String? tenantId) =>
      tenantId != null ? 'cfg_$tenantId' : 'cfg_default';

  static CampaignConfig getConfig(String? tenantId) {
    final raw = _box.get(_configKey(tenantId));
    if (raw == null) return CampaignConfig.defaults;
    try {
      return CampaignConfig.fromJsonString(raw);
    } catch (_) {
      return CampaignConfig.defaults;
    }
  }

  static Future<void> saveConfig(String? tenantId, CampaignConfig config) =>
      _box.put(_configKey(tenantId), config.toJsonString());
}
