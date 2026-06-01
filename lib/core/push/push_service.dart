import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../app.dart' show rootNavigatorKey;
import '../config/app_constants.dart';

class PushService {
  static Future<void> init() async {
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }

    OneSignal.initialize(kOneSignalAppId);

    // Demande la permission (iOS / Android 13+)
    await OneSignal.Notifications.requestPermission(true);

    // Afficher les notifications même quand l'app est au premier plan
    OneSignal.Notifications.addForegroundWillDisplayListener(
      (OSNotificationWillDisplayEvent event) {
        event.notification.display();
      },
    );

    // Gérer le tap sur une notification (app ouverte ou en background)
    OneSignal.Notifications.addClickListener(_onNotificationClicked);
  }

  /// Appeler après login — lie cet appareil à notre userId côté OneSignal
  static Future<void> login(String userId) async {
    await OneSignal.login(userId);
    debugPrint('[Push] Linked to user $userId');
  }

  /// Appeler avant logout — dissocie l'appareil de l'utilisateur
  static Future<void> logout() async {
    await OneSignal.logout();
    debugPrint('[Push] User unlinked');
  }

  // ── Gestion du tap ────────────────────────────────────────────────────────

  static void _onNotificationClicked(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data == null) return;

    final type = data['type'] as String?;
    final bookingId = data['bookingId'] as String?;
    final tripId = data['tripId'] as String?;
    final trackingCode = data['trackingCode'] as String?;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final route = _resolveRoute(type, bookingId: bookingId, tripId: tripId, trackingCode: trackingCode);
    debugPrint('[Push] Navigating to $route (type=$type)');
    GoRouter.of(context).push(route);
  }

  static String _resolveRoute(
    String? type, {
    String? bookingId,
    String? tripId,
    String? trackingCode,
  }) {
    switch (type) {
      case 'BOOKING_CONFIRMED':
      case 'BOOKING_CANCELLED':
      case 'BOOKING_EXPIRED':
      case 'BOARDING_REMINDER':
      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_FAILED':
      case 'TICKET_READY':
        if (bookingId != null) return '/passenger/booking/$bookingId';
        return '/passenger/bookings';
      case 'TRIP_DEPARTED':
      case 'TRIP_ARRIVED':
      case 'TRIP_DELAYED':
      case 'TRIP_CANCELLED':
        if (tripId != null) return '/track/$tripId';
        if (bookingId != null) return '/passenger/booking/$bookingId';
        return '/passenger/bookings';
      case 'TEAM_MEMBER_INVITED':
      case 'TEAM_ROLE_CHANGED':
      case 'TEAM_MEMBER_REMOVED':
        return '/dashboard';
      case 'PARCEL_COLLECTED':
      case 'PARCEL_IN_TRANSIT':
      case 'PARCEL_ARRIVED':
      case 'PARCEL_DELIVERED':
        if (trackingCode != null) return '/parcel/$trackingCode';
        return '/passenger/parcels';
      default:
        return '/passenger/notifications';
    }
  }
}
