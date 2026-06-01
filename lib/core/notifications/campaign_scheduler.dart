import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'campaign_config.dart';
import 'local_notification_service.dart';
import 'notification_prefs_cache.dart';

const _kReEngagementTask = 'transpro.reengagement';

// ── Workmanager callback (isolate séparé) ─────────────────────────────────────
// Doit être une fonction top-level annotée vm:entry-point.

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Hive.initFlutter();
      await NotifPrefsCache.init();
      await LocalNotificationService.initForBackground();

      if (taskName == _kReEngagementTask) {
        await _checkAndFireReEngagement();
      }
    } catch (e) {
      debugPrint('[Workmanager] $taskName: $e');
    }
    return true;
  });
}

Future<void> _checkAndFireReEngagement() async {
  final config = NotifPrefsCache.getConfig(null);
  if (!config.reEngagementEnabled) return;
  if (!NotifPrefsCache.isCampaignEnabled('reEngagement')) return;

  final elapsed = DateTime.now().difference(NotifPrefsCache.lastActiveAt);
  if (elapsed.inDays < config.reEngagementAfterDays) return;

  await LocalNotificationService.showCampaignNow(
    id: LocalNotificationService.reEngagementId,
    title: config.reEngagementTitle,
    body: config.reEngagementBody,
    payload: 'CAMPAIGN_REENGAGEMENT',
  );
}

// ── CampaignScheduler ─────────────────────────────────────────────────────────

class CampaignScheduler {
  /// À appeler une seule fois dans main(), avant runApp().
  static Future<void> init() async {
    await Workmanager().initialize(
      workmanagerCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Applique la config (actuelle du tenant) en tenant compte des prefs
  /// utilisateur. À appeler après login et après tout changement de config.
  static Future<void> applyConfig({
    required CampaignConfig config,
    required String? tenantId,
  }) async {
    await _applyMorning(config);
    await _applyWeekend(config);
    await _applyReEngagement(config);
  }

  /// Annule toutes les campagnes planifiées (appelé au logout).
  static Future<void> cancelAll() async {
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.morningReminderId);
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.weekendOfferId);
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.reEngagementId);
    await Workmanager().cancelByUniqueName(_kReEngagementTask);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static Future<void> _applyMorning(CampaignConfig config) async {
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.morningReminderId);
    if (!config.morningReminderEnabled) return;
    if (!NotifPrefsCache.isCampaignEnabled('morningReminder')) return;

    await LocalNotificationService.scheduleDailyCampaign(
      id: LocalNotificationService.morningReminderId,
      title: config.morningReminderTitle,
      body: config.morningReminderBody,
      hour: config.morningReminderHour,
      minute: config.morningReminderMinute,
      payload: 'CAMPAIGN_MORNING',
    );
  }

  static Future<void> _applyWeekend(CampaignConfig config) async {
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.weekendOfferId);
    if (!config.weekendOfferEnabled) return;
    if (!NotifPrefsCache.isCampaignEnabled('weekendOffer')) return;

    await LocalNotificationService.scheduleWeeklyCampaign(
      id: LocalNotificationService.weekendOfferId,
      title: config.weekendOfferTitle,
      body: config.weekendOfferBody,
      weekday: DateTime.friday,
      hour: config.weekendOfferHour,
      minute: config.weekendOfferMinute,
      payload: 'CAMPAIGN_WEEKEND',
    );
  }

  static Future<void> _applyReEngagement(CampaignConfig config) async {
    await Workmanager().cancelByUniqueName(_kReEngagementTask);
    if (!config.reEngagementEnabled) return;
    if (!NotifPrefsCache.isCampaignEnabled('reEngagement')) return;

    await Workmanager().registerPeriodicTask(
      _kReEngagementTask,
      _kReEngagementTask,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }
}
