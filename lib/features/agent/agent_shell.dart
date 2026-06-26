import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/theme/space_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

class AgentShell extends ConsumerStatefulWidget {
  final Widget child;
  const AgentShell({super.key, required this.child});

  @override
  ConsumerState<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends ConsumerState<AgentShell> {
  io.Socket? _socket;

  static const _tabRoutes = [
    '/agent',
    '/agent/scanner',
    '/agent/guichet',
    '/agent/caisse',
    '/agent/profile',
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
        backgroundColor: isAlert ? const Color(0xFFDC2626) : kAgentColors.primary,
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
          onPressed: () => context.push('/agent/notifications'),
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
    final labels = [l10n.navDepartures, l10n.navScanner, l10n.navGuichet, l10n.navCaisse, l10n.navProfile];
    final user = ref.watch(authProvider).user;

    final location = GoRouterState.of(context).matchedLocation;
    int current = 0;
    int bestLen = -1;
    for (int i = 0; i < _tabRoutes.length; i++) {
      final path = _tabRoutes[i];
      if (location == path || location.startsWith('$path/')) {
        if (path.length > bestLen) { bestLen = path.length; current = i; }
      }
    }

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.departure_board_outlined),
        selectedIcon: Icon(Icons.departure_board),
        label: '',
      ),
      const NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: Icon(Icons.qr_code_scanner),
        label: '',
      ),
      const NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale_rounded),
        label: '',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart_rounded),
        label: '',
      ),
      // Profile tab: shows agent avatar
      NavigationDestination(
        icon: user != null
            ? _AvatarIcon(
                firstName: user.firstName,
                lastName: user.lastName,
                avatar: user.avatar,
                selected: false,
              )
            : const Icon(Icons.person_outline_rounded),
        selectedIcon: user != null
            ? _AvatarIcon(
                firstName: user.firstName,
                lastName: user.lastName,
                avatar: user.avatar,
                selected: true,
              )
            : const Icon(Icons.person_rounded),
        label: '',
      ),
    ];

    return SpaceTheme.wrap(
      context: context,
      colors: kAgentColors,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (i) => context.go(_tabRoutes[i]),
          destinations: List.generate(destinations.length, (i) => NavigationDestination(
            icon: destinations[i].icon,
            selectedIcon: destinations[i].selectedIcon,
            label: labels[i],
          )),
        ),
      ),
    );
  }
}

// ── Avatar icon for profile tab ───────────────────────────────────────────────

class _AvatarIcon extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String? avatar;
  final bool selected;

  const _AvatarIcon({
    required this.firstName,
    required this.lastName,
    this.avatar,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: selected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAgentColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.all(selected ? 1.0 : 0.0),
        child: UserAvatarWidget(
          firstName: firstName,
          lastName: lastName,
          avatar: avatar,
          size: 24,
        ),
      ),
    );
  }
}
