import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/notification_providers.dart' show unreadCountProvider;

class PassengerShell extends ConsumerStatefulWidget {
  final Widget child;
  const PassengerShell({super.key, required this.child});

  @override
  ConsumerState<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends ConsumerState<PassengerShell> {
  io.Socket? _socket;

  static const _tabs = [
    ('/passenger',          Icons.home_outlined,            Icons.home_rounded,            'Accueil'),
    ('/passenger/search',   Icons.search_outlined,           Icons.search_rounded,          'Recherche'),
    ('/passenger/bookings', Icons.confirmation_num_outlined, Icons.confirmation_num_rounded,'Billets'),
    ('/passenger/profile',  Icons.person_outline_rounded,   Icons.person_rounded,          'Profil'),
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
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () => context.push('/passenger/notifications'),
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
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.$1));
    final current = idx == -1 ? 0 : idx;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.$2),
          selectedIcon: Icon(t.$3),
          label: t.$4,
        )).toList(),
      ),
    );
  }
}
