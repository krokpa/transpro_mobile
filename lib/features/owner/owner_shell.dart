import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class OwnerShell extends ConsumerStatefulWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  io.Socket? _socket;

  static const _tabDefs = [
    ('/owner',         Icons.bar_chart_outlined,       Icons.bar_chart_rounded),
    ('/owner/trips',   Icons.departure_board_outlined, Icons.departure_board),
    ('/owner/fleet',   Icons.directions_bus_outlined,  Icons.directions_bus_rounded),
    ('/owner/routes',  Icons.alt_route_outlined,       Icons.alt_route_rounded),
    ('/owner/profile', Icons.person_outline_rounded,   Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;

    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.on('notification', (data) {
      if (!mounted) return;
      ref.invalidate(unreadCountProvider);
      final title   = data['title']   as String? ?? 'Notification';
      final message = data['message'] as String? ?? '';
      _showBanner(title, message, data['type'] as String?);
    });

    _socket!.connect();
  }

  void _showBanner(String title, String message, String? type) {
    final isAlert = type == 'TRIP_CANCELLED' || type == 'TRIP_DELAYED';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: isAlert ? const Color(0xFFDC2626) : brandOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (message.isNotEmpty)
            Text(message, style: const TextStyle(fontSize: 13)),
        ]),
        action: SnackBarAction(
          label: AppLocalizations.of(context).see,
          textColor: Colors.white,
          onPressed: () => context.push('/owner/notifications'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.navDashboard, l10n.navTrips, l10n.navFleet, l10n.navRoutes, l10n.navProfile];

    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabDefs.indexWhere((t) => location == t.$1);
    final current = idx == -1 ? 0 : idx;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) => context.go(_tabDefs[i].$1),
        destinations: List.generate(_tabDefs.length, (i) => NavigationDestination(
          icon: Icon(_tabDefs[i].$2),
          selectedIcon: Icon(_tabDefs[i].$3),
          label: labels[i],
        )),
      ),
    );
  }
}
