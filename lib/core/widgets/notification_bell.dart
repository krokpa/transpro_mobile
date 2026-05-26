import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_providers.dart';

/// Bell icon with red unread-count badge. Pass [notificationsRoute] so it
/// pushes to the right route for the current role.
class NotificationBell extends ConsumerWidget {
  final String notificationsRoute;
  final Color iconColor;
  const NotificationBell({
    super.key,
    required this.notificationsRoute,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          onPressed: () => context.push(notificationsRoute),
        ),
        if (count > 0)
          Positioned(
            top: 8, right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
