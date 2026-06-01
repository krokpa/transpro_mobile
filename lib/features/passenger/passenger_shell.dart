import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/notifications/campaign_scheduler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/notification_providers.dart' show unreadCountProvider;
import '../../core/providers/favorites_provider.dart';
import '../../core/widgets/user_avatar.dart';
import '../../l10n/app_localizations.dart';

/// InheritedWidget qui expose le callback openDrawer() aux écrans enfants,
/// sans passer par un GlobalKey statique (qui provoquerait des conflits lors
/// des transitions GoRouter où deux instances du shell coexistent brièvement).
class PassengerShellScope extends InheritedWidget {
  final VoidCallback openDrawer;

  const PassengerShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  static PassengerShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassengerShellScope>();

  @override
  bool updateShouldNotify(PassengerShellScope old) => openDrawer != old.openDrawer;
}

class PassengerShell extends ConsumerStatefulWidget {
  final Widget child;
  const PassengerShell({super.key, required this.child});

  @override
  ConsumerState<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends ConsumerState<PassengerShell> {
  /// Clé d'instance (non statique) — chaque instance du shell a la sienne.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
    final tenantId = ref.read(authProvider).user?.tenantId;
    CampaignScheduler.onAppOpen(tenantId).ignore();
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

    return PassengerShellScope(
      openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _PassengerDrawer(favs: favs, l10n: l10n),
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
      ),
    );
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────

class _PassengerDrawer extends ConsumerWidget {
  final FavoritesState favs;
  final AppLocalizations l10n;
  const _PassengerDrawer({required this.favs, required this.l10n});

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.go(route);
  }

  void _push(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(authProvider).user;
    final favoriteCount = favs.companies.length + favs.stations.length;
    final location      = GoRouterState.of(context).matchedLocation;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.83,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _DrawerHeader(user: user, l10n: l10n, onTap: () => _go(context, '/passenger/profile')),

          // ── Nav items ─────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // PRINCIPAL
                _SectionLabel('PRINCIPAL'),
                _NavItem(
                  icon: Icons.home_rounded,
                  label: l10n.navHome,
                  color: brandOrange,
                  active: location == '/passenger',
                  onTap: () => _go(context, '/passenger'),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  label: l10n.navSearch,
                  color: brandOrange,
                  active: location.startsWith('/passenger/search'),
                  onTap: () => _go(context, '/passenger/search'),
                ),
                _NavItem(
                  icon: Icons.confirmation_num_rounded,
                  label: l10n.navTickets,
                  color: const Color(0xFF6366F1),
                  active: location.startsWith('/passenger/booking'),
                  onTap: () => _go(context, '/passenger/bookings'),
                ),

                const SizedBox(height: 4),
                _Divider(),

                // COLIS
                _SectionLabel('COLIS'),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Mes colis',
                  color: const Color(0xFF0EA5E9),
                  active: location == '/passenger/parcels',
                  onTap: () => _push(context, '/passenger/parcels'),
                ),
                _NavItem(
                  icon: Icons.outbox_rounded,
                  label: 'Envoyer un colis',
                  color: const Color(0xFF0EA5E9),
                  active: location == '/passenger/parcels/send',
                  onTap: () => _push(context, '/passenger/parcels/send'),
                ),
                _NavItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Suivre un colis',
                  color: const Color(0xFF0EA5E9),
                  active: location.startsWith('/parcel'),
                  onTap: () => _push(context, '/parcel'),
                ),

                const SizedBox(height: 4),
                _Divider(),

                // COMPTE & PLUS
                _SectionLabel('COMPTE & PLUS'),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: l10n.transactionsDrawerLabel,
                  color: const Color(0xFF10B981),
                  active: location.startsWith('/passenger/transactions'),
                  onTap: () => _push(context, '/passenger/transactions'),
                ),
                _NavItem(
                  icon: Icons.star_rounded,
                  label: l10n.favoritesTitle,
                  color: const Color(0xFFF59E0B),
                  active: location.startsWith('/passenger/favorites'),
                  badge: favoriteCount > 0 ? '$favoriteCount' : null,
                  onTap: () => _push(context, '/passenger/favorites'),
                ),
                _NavItem(
                  icon: Icons.business_rounded,
                  label: l10n.companiesTitle,
                  color: const Color(0xFFF59E0B),
                  active: location.startsWith('/passenger/companies'),
                  onTap: () => _push(context, '/passenger/companies'),
                ),
                _NavItem(
                  icon: Icons.notifications_rounded,
                  label: l10n.notificationsTitle,
                  color: const Color(0xFF8B5CF6),
                  active: location.startsWith('/passenger/notifications'),
                  onTap: () => _push(context, '/passenger/notifications'),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: l10n.navProfile,
                  color: brandOrange,
                  active: location.startsWith('/passenger/profile'),
                  onTap: () => _go(context, '/passenger/profile'),
                ),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          _DrawerFooter(ref: ref, l10n: l10n),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final User? user;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _DrawerHeader({required this.user, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [brandCanvas, Color(0xFF1A3A5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Blobs décoratifs
            Positioned(
              top: -20, right: -20,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandOrange.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -10, left: -15,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Contenu
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + badge rôle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: brandOrange.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: UserAvatarWidget(
                            firstName: user?.firstName ?? '',
                            lastName: user?.lastName ?? '',
                            avatar: user?.avatar,
                            size: 64,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: brandOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: brandOrange.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            l10n.passengerRole,
                            style: const TextStyle(
                              color: brandOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Nom
                    Text(
                      user?.fullName ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Email
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),

                    const SizedBox(height: 14),

                    // Lien profil
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          l10n.navProfile,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _DrawerFooter extends StatelessWidget {
  final WidgetRef ref;
  final AppLocalizations l10n;
  const _DrawerFooter({required this.ref, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: context.divider),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                // Brand
                Row(
                  children: [
                    Icon(Icons.directions_bus_rounded, size: 15, color: context.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'TransPro CI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Déconnexion
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFDC2626)),
                  label: Text(
                    l10n.settingsLogout,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

// ── Helpers visuels ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: context.textMuted,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 20, endIndent: 20, color: context.divider);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active
            ? color.withValues(alpha: context.isDark ? 0.18 : 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? color.withValues(alpha: 0.18)
                        : color.withValues(alpha: context.isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: active ? color : color.withValues(alpha: 0.8)),
                ),
                const SizedBox(width: 12),
                // Label
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? color : context.textPrimary,
                    ),
                  ),
                ),
                // Badge ou chevron
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  )
                else if (active)
                  Icon(Icons.circle, size: 6, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
