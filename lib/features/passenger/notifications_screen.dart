import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/theme/app_theme.dart';

export '../../core/providers/notification_providers.dart'
    show notificationsProvider, unreadCountProvider;

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notifAsync.whenOrNull(
            data: (list) {
              final hasUnread = list.any((n) => !n.isRead);
              if (!hasUnread) return null;
              return TextButton(
                onPressed: () => _markAllRead(ref),
                child: const Text('Tout lire', style: TextStyle(color: brandOrange)),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucune notification', style: TextStyle(color: Colors.grey[400])),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/notifications/my/read-all');
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  static const _typeIcons = <String, (IconData, Color)>{
    'BOOKING_CONFIRMED': (Icons.check_circle_outline, Color(0xFF16A34A)),
    'BOOKING_CANCELLED': (Icons.cancel_outlined,      Color(0xFFDC2626)),
    'TRIP_DEPARTED':     (Icons.directions_bus,        Color(0xFF0369A1)),
    'TRIP_BOARDING':     (Icons.door_front_door_outlined, Color(0xFFCA8A04)),
    'TRIP_CANCELLED':    (Icons.warning_amber_outlined, Color(0xFFDC2626)),
    'TRIP_DELAYED':      (Icons.update,                Color(0xFFD97706)),
    'PAYMENT_RECEIVED':  (Icons.payments_outlined,     Color(0xFF16A34A)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _typeIcons[notification.type] ?? (Icons.notifications_outlined, brandOrange);
    final ago = _timeAgo(notification.createdAt);

    return Container(
      color: notification.isRead ? null : const Color(0xFFFFF7ED),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: cfg.$2.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cfg.$1, color: cfg.$2, size: 22),
        ),
        title: Text(notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
            fontSize: 14,
            color: brandDark,
          ),
        ),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(notification.message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(ago, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
        trailing: notification.isRead ? null : Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: brandOrange, shape: BoxShape.circle),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('d MMM', 'fr_FR').format(dt);
  }
}
