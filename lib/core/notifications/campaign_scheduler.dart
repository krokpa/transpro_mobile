import 'package:timezone/timezone.dart' as tz;
import 'campaign_config.dart';
import 'local_notification_service.dart';
import 'notification_prefs_cache.dart';

// ── CampaignScheduler ─────────────────────────────────────────────────────────
//
// Stratégie ré-engagement sans Workmanager :
//   • À chaque ouverture de l'app (PassengerShell.initState), on annule la
//     notification en cours et on en planifie une nouvelle dans N jours.
//   • Si l'utilisateur n'ouvre pas l'app pendant N jours, la notification
//     se déclenche. Dès qu'il rouvre l'app, le cycle repart.

class CampaignScheduler {
  /// Initialisation — rien à faire sans Workmanager.
  static Future<void> init() async {}

  /// (Re)programme toutes les campagnes selon la config + prefs utilisateur.
  /// À appeler après login et après chaque changement de config/prefs.
  static Future<void> applyConfig({
    required CampaignConfig config,
    required String? tenantId,
  }) async {
    await _applyMorning(config);
    await _applyWeekend(config);
    await _applyReEngagement(config);
  }

  /// À appeler à chaque ouverture de l'app (PassengerShell.initState).
  /// Réinitialise le compteur d'inactivité en reschedulant la notification.
  static Future<void> onAppOpen(String? tenantId) async {
    await NotifPrefsCache.markActive();
    final config = NotifPrefsCache.getConfig(tenantId);
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
    await LocalNotificationService.cancelCampaign(
        LocalNotificationService.reEngagementId);
    if (!config.reEngagementEnabled) return;
    if (!NotifPrefsCache.isCampaignEnabled('reEngagement')) return;

    // Planifie une notification one-shot dans N jours à partir de maintenant.
    // À chaque ouverture de l'app, cette notification est annulée et
    // reschedulée — ce qui repart le compteur d'inactivité.
    final fireAt = tz.TZDateTime.now(tz.local)
        .add(Duration(days: config.reEngagementAfterDays));

    await LocalNotificationService.scheduleReEngagement(
      scheduledAt: fireAt,
      title: config.reEngagementTitle,
      body: config.reEngagementBody,
    );
  }
}
