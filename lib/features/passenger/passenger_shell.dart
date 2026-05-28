import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/notification_providers.dart' show unreadCountProvider;
import '../../core/providers/favorites_provider.dart';
import '../../l10n/app_localizations.dart';

class PassengerShell extends ConsumerStatefulWidget {
  final Widget child;
  const PassengerShell({super.key, required this.child});

  @override
  ConsumerState<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends ConsumerState<PassengerShell> {
  io.Socket? _socket;

  static const _tabDefs = [
    ('/passenger',          Icons.home_outlined,            Icons.home_rounded),
    ('/passenger/search',   Icons.search_outlined,          Icons.search_rounded),
    ('/passenger/bookings', Icons.confirmation_num_outlined, Icons.confirmation_num_rounded),
    ('/passenger/profile',  Icons.person_outline_rounded,   Icons.person_rounded),
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
    final l10n = AppLocalizations.of(context);
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
          label: l10n.see,
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
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.navHome, l10n.navSearch, l10n.navTickets, l10n.navProfile];
    final user = ref.watch(authProvider).user;
    final favs = ref.watch(favoritesProvider);

    final location = GoRouterState.of(context).matchedLocation;
    int current = 0;
    int bestLen = -1;
    for (int i = 0; i < _tabDefs.length; i++) {
      final path = _tabDefs[i].$1;
      if (location == path || location.startsWith('$path/')) {
        if (path.length > bestLen) { bestLen = path.length; current = i; }
      }
    }

    return Scaffold(
      drawer: _PassengerDrawer(user: user, favs: favs, l10n: l10n),
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

// ── Drawer ────────────────────────────────────────────────────────────────────

class _PassengerDrawer extends StatelessWidget {
  final User? user;
  final FavoritesState favs;
  final AppLocalizations l10n;
  const _PassengerDrawer({
    required this.user,
    required this.favs,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteCount = favs.companies.length + favs.stations.length;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandCanvas, Color(0xFF1A3A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: brandOrange.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user != null ? user!.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user != null ? '${user!.firstName} ${user!.lastName}' : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (user != null)
                    Text(
                      user!.email,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Navigation items ────────────────────────────────────────────
            _DrawerItem(
              icon: Icons.home_rounded,
              label: l10n.navHome,
              onTap: () {
                Navigator.pop(context);
                context.go('/passenger');
              },
            ),
            _DrawerItem(
              icon: Icons.business_rounded,
              label: l10n.companiesTitle,
              onTap: () {
                Navigator.pop(context);
                context.push('/passenger/companies');
              },
            ),
            _DrawerItem(
              icon: Icons.star_rounded,
              label: l10n.favoritesTitle,
              badge: favoriteCount > 0 ? '$favoriteCount' : null,
              onTap: () {
                Navigator.pop(context);
                context.push('/passenger/favorites');
              },
            ),
            _DrawerItem(
              icon: Icons.inventory_2_outlined,
              label: 'Mes colis envoyés',
              onTap: () {
                Navigator.pop(context);
                context.push('/passenger/parcels');
              },
            ),
            _DrawerItem(
              icon: Icons.send_rounded,
              label: 'Envoyer un colis',
              onTap: () {
                Navigator.pop(context);
                context.push('/passenger/parcels/send');
              },
            ),
            _DrawerItem(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Suivre un colis',
              onTap: () {
                Navigator.pop(context);
                context.push('/parcel');
              },
            ),
            _DrawerItem(
              icon: Icons.notifications_outlined,
              label: l10n.notificationsTitle,
              onTap: () {
                Navigator.pop(context);
                context.push('/passenger/notifications');
              },
            ),

            const Divider(height: 24, indent: 16, endIndent: 16),

            _DrawerItem(
              icon: Icons.person_outline_rounded,
              label: l10n.navProfile,
              onTap: () {
                Navigator.pop(context);
                context.go('/passenger/profile');
              },
            ),

            const Spacer(),

            // ── Footer ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'TransPro CI',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: context.textSecondary, size: 22),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.textPrimary,
      ),
    ),
    trailing: badge != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: brandOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null,
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
