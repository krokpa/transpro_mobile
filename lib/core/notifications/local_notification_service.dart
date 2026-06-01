import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../app.dart' show rootNavigatorKey;

// ── Notification channel IDs ──────────────────────────────────────────────────

const _kChannelTransactional = 'transpro_transactional';
const _kChannelTrip          = 'transpro_trip';
const _kChannelCampaign      = 'transpro_campaign';

// ── Notification IDs ──────────────────────────────────────────────────────────
// 1000–1999 : booking reminders
// 2001      : morning reminder
// 2002      : weekend offer
// 2003      : re-engagement

// Background tap handler — must be top-level, annotated vm:entry-point.
// Navigation is not possible in this isolate; handled on app resume.
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(NotificationResponse response) {}

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // IDs publics utilisés par CampaignScheduler
  static const int morningReminderId = 2001;
  static const int weekendOfferId    = 2002;
  static const int reEngagementId    = 2003;

  // ── Initialisation principale (avec gestion du tap) ───────────────────────────

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onForegroundTap,
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundResponseHandler,
    );

    await _createChannels();
  }

  // Initialisation légère pour le Workmanager (isolate background, sans navigation)
  static Future<void> initForBackground() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _createChannels();
  }

  // ── Canaux Android ────────────────────────────────────────────────────────────

  static Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelTransactional, 'Transactions',
      description: 'Confirmations de réservation et paiements',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelTrip, 'Voyages',
      description: 'Rappels de départ et alertes de trajet',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelCampaign, 'Offres & Actualités',
      description: 'Rappels et offres personnalisées de TransPro',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    ));
  }

  // ── Transactionnelles (immédiates) ────────────────────────────────────────────

  static Future<void> showTransactional({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? subText,
  }) =>
      _plugin.show(
        id, title, body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelTransactional, 'Transactions',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFFF97316),
            subText: subText,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
          ),
          iOS: const DarwinNotificationDetails(threadIdentifier: 'transactional'),
        ),
        payload: payload,
      );

  // ── Rappel départ H-2 (planifié à la réservation) ─────────────────────────────

  static Future<void> scheduleBookingReminder({
    required String bookingId,
    required String origin,
    required String destination,
    required DateTime departureAt,
  }) async {
    final reminderAt = departureAt.subtract(const Duration(hours: 2));
    if (!reminderAt.isAfter(DateTime.now())) return;

    final timeStr = DateFormat('HH:mm').format(departureAt);

    await _plugin.zonedSchedule(
      _bookingNotifId(bookingId),
      'Départ dans 2h — $origin → $destination',
      'Votre véhicule part à $timeStr. Préparez votre billet !',
      tz.TZDateTime.from(reminderAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelTrip, 'Voyages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFFF97316),
          styleInformation: BigTextStyleInformation(
            'Votre véhicule $origin → $destination part à $timeStr.\n'
            'Présentez votre billet au guichet.',
          ),
          actions: [
            const AndroidNotificationAction(
              'view_ticket', 'Voir le billet',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: 'trip_$bookingId',
          subtitle: '$origin → $destination',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'BOOKING_REMINDER:$bookingId',
    );
  }

  static Future<void> cancelBookingReminder(String bookingId) =>
      _plugin.cancel(_bookingNotifId(bookingId));

  // ── Campagnes planifiées ──────────────────────────────────────────────────────

  static Future<void> scheduleDailyCampaign({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) =>
      _plugin.zonedSchedule(
        id, title, body,
        _nextDailyTime(hour, minute),
        _campaignDetails(title, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );

  static Future<void> scheduleWeeklyCampaign({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  }) =>
      _plugin.zonedSchedule(
        id, title, body,
        _nextWeekdayTime(weekday, hour, minute),
        _campaignDetails(title, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );

  static Future<void> showCampaignNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      _plugin.show(id, title, body, _campaignDetails(title, body),
          payload: payload);

  // Notification one-shot pour le ré-engagement (annulée + reschedulée à
  // chaque ouverture de l'app via CampaignScheduler.onAppOpen).
  static Future<void> scheduleReEngagement({
    required tz.TZDateTime scheduledAt,
    required String title,
    required String body,
  }) =>
      _plugin.zonedSchedule(
        reEngagementId,
        title,
        body,
        scheduledAt,
        _campaignDetails(title, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'CAMPAIGN_REENGAGEMENT',
      );

  static Future<void> cancelCampaign(int id) => _plugin.cancel(id);

  // ── Gestion du tap sur notification ──────────────────────────────────────────

  static void _onForegroundTap(NotificationResponse response) =>
      _navigate(response.payload);

  // Appelé depuis main.dart — gère le cas app lancée depuis une notif
  static Future<void> handleLaunchDetails() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      _navigate(details!.notificationResponse?.payload);
    }
  }

  static void _navigate(String? payload) {
    if (payload == null) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    if (payload.startsWith('BOOKING_REMINDER:')) {
      final id = payload.substring('BOOKING_REMINDER:'.length);
      GoRouter.of(ctx).push('/passenger/booking/$id');
    } else if (payload == 'CAMPAIGN_MORNING' || payload == 'CAMPAIGN_WEEKEND') {
      GoRouter.of(ctx).push('/passenger/search');
    } else if (payload == 'CAMPAIGN_REENGAGEMENT') {
      GoRouter.of(ctx).go('/passenger');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static NotificationDetails _campaignDetails(String title, String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelCampaign, 'Offres & Actualités',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFFF97316),
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          threadIdentifier: 'campaign',
          interruptionLevel: InterruptionLevel.passive,
        ),
      );

  static int _bookingNotifId(String bookingId) =>
      1000 + (bookingId.hashCode.abs() % 999);

  static tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    var t = _nextDailyTime(hour, minute);
    var safety = 0;
    while (t.weekday != weekday && safety++ < 7) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}
