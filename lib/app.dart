import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/auth/auth_provider.dart';
import 'core/l10n/locale_provider.dart';
import 'core/settings/settings_cache.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/walkthrough_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/pin_setup_screen.dart';
import 'features/auth/pin_login_screen.dart';
import 'features/passenger/passenger_shell.dart';
import 'features/passenger/home_screen.dart';
import 'features/passenger/search_screen.dart';
import 'features/passenger/bookings_screen.dart';
import 'features/passenger/booking_detail_screen.dart';
import 'features/passenger/notifications_screen.dart';
import 'features/passenger/profile_screen.dart';
import 'features/agent/agent_shell.dart';
import 'features/agent/agent_profile_screen.dart';
import 'features/agent/departures_screen.dart';
import 'features/agent/manifest_screen.dart';
import 'features/agent/scanner_screen.dart';
import 'features/agent/guichet_screen.dart';
import 'features/agent/quick_sale_screen.dart';
import 'features/agent/caisse_screen.dart';
import 'features/owner/owner_shell.dart';
import 'features/owner/dashboard_screen.dart';
import 'features/owner/setup_stepper_screen.dart';
import 'features/owner/drivers_screen.dart';
import 'features/owner/driver_detail_screen.dart';
import 'features/owner/fleet_screen.dart';
import 'features/owner/vehicle_detail_screen.dart';
import 'features/owner/reports_screen.dart';
import 'features/owner/routes_screen.dart';
import 'features/owner/schedules_screen.dart';
import 'features/owner/staff_screen.dart';
import 'features/owner/stations_screen.dart';
import 'features/owner/trips_screen.dart';
import 'features/owner/owner_profile_screen.dart';
import 'features/passenger/trip_tracking_screen.dart';
import 'features/passenger/payment_success_screen.dart';
import 'features/passenger/payment_error_screen.dart';
import 'features/passenger/company_detail_screen.dart';
import 'features/passenger/station_detail_screen.dart';
import 'features/passenger/station_navigation_screen.dart';
import 'features/passenger/companies_screen.dart';
import 'features/passenger/favorites_screen.dart';
import 'features/passenger/parcel_tracking_screen.dart';
import 'features/passenger/my_parcels_screen.dart';
import 'features/passenger/send_parcel_screen.dart';
import 'features/passenger/transactions_screen.dart';
import 'features/agent/agent_parcels_screen.dart';
import 'features/agent/parcel_scan_screen.dart';
import 'features/passenger/delivery_request_screen.dart';
import 'features/agent/agent_luggage_screen.dart';
import 'features/passenger/passenger_luggage_screen.dart';
import 'features/passenger/notification_settings_screen.dart';
import 'features/owner/campaign_settings_screen.dart';
import 'features/driver/driver_shell.dart';
import 'features/driver/driver_home_screen.dart';
import 'features/driver/driver_trips_screen.dart';
import 'features/driver/driver_profile_screen.dart';
import 'features/driver/driver_settings_screen.dart';

/// Clé globale du navigateur racine — utilisée par PushService pour naviguer
/// hors du contexte widget (ex. tap sur une notification push).
final rootNavigatorKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Auth-driven redirect logic extracted into a ChangeNotifier so the GoRouter
// stays stable and is never recreated on auth state changes.
// Only notifies on routing-relevant state changes to avoid triggering
// GoRouter.refresh() during in-progress navigations (e.g. profile updates,
// biometric toggles, or token refreshes that don't affect the current route).
// ---------------------------------------------------------------------------
class _AuthListenable extends ChangeNotifier {
  final Ref _ref;

  _AuthListenable(this._ref) {
    _ref.listen<AuthState>(authProvider, _onAuthChange);
  }

  void _onAuthChange(AuthState? prev, AuthState next) {
    if (prev == null ||
        prev.isLoading != next.isLoading ||
        prev.isAuthenticated != next.isAuthenticated ||
        prev.pinVerified != next.pinVerified ||
        prev.hasPinSet != next.hasPinSet ||
        prev.user?.role != next.user?.role) {
      notifyListeners();
    }
  }

  String get initialLocation {
    final auth = _ref.read(authProvider);
    if (auth.isLoading) return '/splash';
    if (!auth.isAuthenticated) return '/login';
    if (auth.user!.isPassenger) return '/passenger';
    if (auth.user!.isAgent) return '/agent';
    if (auth.user!.isOwner) return '/owner';
    if (auth.user!.isDriver) return '/driver';
    return '/login';
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);

    final uri = state.uri;
    if (uri.scheme == 'transpro' && uri.host == 'track') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.isNotEmpty) return '/track/$id';
    }
    if (uri.scheme == 'transpro' && uri.host == 'booking') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.isNotEmpty) return '/passenger/booking/$id';
    }
    if (uri.scheme == 'transpro' && uri.host == 'parcel') {
      final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (code.isNotEmpty) return '/parcel/$code';
    }

    if (auth.isLoading) return '/splash';

    final authenticated = auth.isAuthenticated;
    final loc = state.matchedLocation;
    final isAuthRoute = loc.startsWith('/login') ||
        loc.startsWith('/register') ||
        loc.startsWith('/forgot-password');
    final isPinRoute = loc == '/pin-login' || loc == '/pin-setup';
    final isPublicRoute =
        loc.startsWith('/track/') || loc.startsWith('/parcel/');

    if (!authenticated && !isAuthRoute && !isPublicRoute) return '/login';

    if (authenticated && !isPinRoute && !isPublicRoute) {
      if (auth.hasPinSet && !auth.pinVerified) return '/pin-login';
      if (!auth.hasPinSet) return '/pin-setup';
      if (auth.pinVerified &&
          auth.user!.isPassenger &&
          !SettingsCache.onboardingDone &&
          loc != '/onboarding') {
        return '/onboarding';
      }
      // ── Walkthrough première connexion par rôle ─────────────────────────
      if (auth.pinVerified &&
          auth.user!.isDriver &&
          !SettingsCache.walkthroughDone('driver') &&
          loc != '/driver-onboarding') {
        return '/driver-onboarding';
      }
      if (auth.pinVerified &&
          auth.user!.isOwner &&
          !SettingsCache.walkthroughDone('owner') &&
          loc != '/owner-onboarding') {
        return '/owner-onboarding';
      }
      if (auth.pinVerified &&
          auth.user!.isAgent &&
          !SettingsCache.walkthroughDone('agent') &&
          loc != '/agent-onboarding') {
        return '/agent-onboarding';
      }
      if (isAuthRoute) {
        if (auth.user!.isPassenger) return '/passenger';
        if (auth.user!.isAgent) return '/agent';
        if (auth.user!.isOwner) return '/owner';
        if (auth.user!.isDriver) return '/driver';
      }
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// Stable router — created once for the lifetime of the ProviderScope.
// Auth changes trigger redirect re-evaluation via refreshListenable, not
// a new GoRouter instance.
// ---------------------------------------------------------------------------
final _routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  // Explicit navigator keys for ShellRoutes prevent duplicate-page-key
  // assertions in go_router when navigating between sibling shell tabs.
  final passengerShellKey = GlobalKey<NavigatorState>(debugLabel: 'passengerShell');
  final agentShellKey     = GlobalKey<NavigatorState>(debugLabel: 'agentShell');
  final ownerShellKey     = GlobalKey<NavigatorState>(debugLabel: 'ownerShell');
  final driverShellKey    = GlobalKey<NavigatorState>(debugLabel: 'driverShell');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: notifier.initialLocation,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash',     builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/driver-onboarding', builder: (_, _) => const WalkthroughScreen(
        roleKey: 'driver', homeRoute: '/driver', slides: kDriverSlides)),
      GoRoute(path: '/owner-onboarding', builder: (_, _) => const WalkthroughScreen(
        roleKey: 'owner', homeRoute: '/owner', slides: kOwnerSlides)),
      GoRoute(path: '/agent-onboarding', builder: (_, _) => const WalkthroughScreen(
        roleKey: 'agent', homeRoute: '/agent', slides: kAgentSlides)),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/login',           builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register',        builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/pin-setup',       builder: (_, _) => const PinSetupScreen()),
      GoRoute(path: '/pin-login',       builder: (_, _) => const PinLoginScreen()),

      // ── Passenger ─────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: passengerShellKey,
        builder: (_, __, child) => PassengerShell(child: child),
        routes: [
          GoRoute(path: '/passenger',          builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/passenger/search',
            builder: (_, s) {
              final q = s.uri.queryParameters;
              return SearchScreen(
                originName: q['origin'],
                destName: q['destination'],
                dateIso: q['date'],
                passengers: int.tryParse(q['passengers'] ?? ''),
              );
            },
          ),
          GoRoute(path: '/passenger/bookings', builder: (_, _) => const BookingsScreen()),
          GoRoute(path: '/passenger/profile',  builder: (_, _) => const PassengerProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/passenger/booking/:id',
        builder: (_, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/passenger/trip/:id',
        builder: (_, state) => BookingCreateScreen(tripId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/passenger/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/passenger/payment/success/:bookingId',
        builder: (_, state) => PaymentSuccessScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      GoRoute(
        path: '/passenger/payment/error/:bookingId',
        builder: (_, state) => PaymentErrorScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      GoRoute(
        path: '/passenger/company/:slug',
        builder: (_, state) => CompanyDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/passenger/station/:id',
        builder: (_, state) => StationDetailScreen(stationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/passenger/navigate-to-station',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return StationNavigationScreen(
            stationName: extra['name'] as String,
            stationLat: (extra['lat'] as num).toDouble(),
            stationLng: (extra['lng'] as num).toDouble(),
          );
        },
      ),
      GoRoute(
        path: '/passenger/companies',
        builder: (_, _) => const CompaniesScreen(),
      ),
      GoRoute(
        path: '/passenger/favorites',
        builder: (_, _) => const FavoritesScreen(),
      ),

      // ── Agent ─────────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: agentShellKey,
        builder: (_, __, child) => AgentShell(child: child),
        routes: [
          GoRoute(path: '/agent',         builder: (_, _) => const DeparturesScreen()),
          GoRoute(path: '/agent/scanner', builder: (_, state) => ScannerScreen(tripId: state.uri.queryParameters['tripId'])),
          GoRoute(path: '/agent/guichet', builder: (_, _) => const GuichetScreen()),
          GoRoute(path: '/agent/caisse',  builder: (_, _) => const CaisseScreen()),
          GoRoute(path: '/agent/profile', builder: (_, _) => const AgentProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/agent/manifest/:tripId',
        builder: (_, state) => ManifestScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/agent/quick-sale',
        builder: (_, _) => const QuickSaleScreen(),
      ),
      GoRoute(
        path: '/agent/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),

      // ── Public trip tracking (no auth required) ───────────────────────────
      GoRoute(
        path: '/track/:tripId',
        builder: (_, state) => TripTrackingScreen(tripId: state.pathParameters['tripId']!),
      ),

      // ── Public parcel tracking (no auth required) ─────────────────────────
      GoRoute(
        path: '/parcel',
        builder: (_, _) => const ParcelTrackingScreen(),
      ),
      GoRoute(
        path: '/parcel/:code',
        builder: (_, state) => ParcelTrackingScreen(
          initialCode: state.pathParameters['code'],
        ),
      ),

      // ── Home delivery request ─────────────────────────────────────────────
      GoRoute(
        path: '/delivery-request/:code',
        builder: (_, state) => DeliveryRequestScreen(
          trackingCode: Uri.decodeComponent(state.pathParameters['code']!),
        ),
      ),

      // ── Agent: ticket scanner pushed from manifest (root navigator, no shell) ──
      GoRoute(
        path: '/agent/scan-ticket',
        builder: (_, state) => ScannerScreen(
          tripId: state.uri.queryParameters['tripId'],
        ),
      ),

      // ── Agent: luggage management for a trip ──────────────────────────────
      GoRoute(
        path: '/agent/luggage/:tripId',
        builder: (_, state) => AgentLuggageScreen(tripId: state.pathParameters['tripId']!),
      ),

      // ── Passenger: view luggage for a booking ─────────────────────────────
      GoRoute(
        path: '/passenger/booking/:id/luggage',
        builder: (_, state) => PassengerLuggageScreen(
          bookingId: state.pathParameters['id']!,
          bookingRef: state.uri.queryParameters['ref'] ?? '',
        ),
      ),

      // ── Passenger parcel list ─────────────────────────────────────────────
      GoRoute(
        path: '/passenger/parcels',
        builder: (_, _) => const MyParcelsScreen(),
      ),
      GoRoute(
        path: '/passenger/parcels/send',
        builder: (_, _) => const SendParcelScreen(),
      ),

      // ── Passenger: transactions ───────────────────────────────────────────
      GoRoute(
        path: '/passenger/transactions',
        builder: (_, _) => const TransactionsScreen(),
      ),

      // ── Agent: parcel list for a trip ─────────────────────────────────────
      GoRoute(
        path: '/agent/parcels/:tripId',
        builder: (_, state) => AgentParcelsScreen(
          tripId: state.pathParameters['tripId']!,
        ),
      ),

      // ── Agent: parcel QR scanner ──────────────────────────────────────────
      GoRoute(
        path: '/agent/parcel-scan/:tripId',
        builder: (_, state) => ParcelScanScreen(
          tripId: state.pathParameters['tripId'],
        ),
      ),
      GoRoute(
        path: '/agent/parcel-scan',
        builder: (_, _) => const ParcelScanScreen(),
      ),

      GoRoute(path: '/driver/settings', builder: (_, _) => const DriverSettingsScreen()),

      // ── Driver ────────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: driverShellKey,
        builder: (_, __, child) => DriverShell(child: child),
        routes: [
          GoRoute(path: '/driver',          builder: (_, _) => const DriverHomeScreen()),
          GoRoute(path: '/driver/trips',    builder: (_, _) => const DriverTripsScreen()),
          GoRoute(path: '/driver/schedule', builder: (_, _) => const DriverTripsScreen()),
          GoRoute(path: '/driver/profile',  builder: (_, _) => const DriverProfileScreen()),
        ],
      ),

      // ── Owner ─────────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: ownerShellKey,
        builder: (_, __, child) => OwnerShell(child: child),
        routes: [
          GoRoute(path: '/owner',         builder: (_, _) => const OwnerDashboardScreen()),
          GoRoute(path: '/owner/trips',   builder: (_, _) => const OwnerTripsScreen()),
          GoRoute(path: '/owner/fleet',   builder: (_, _) => const FleetScreen()),
          GoRoute(path: '/owner/routes',  builder: (_, _) => const OwnerRoutesScreen()),
          GoRoute(path: '/owner/profile', builder: (_, _) => const OwnerProfileScreen()),
        ],
      ),
      GoRoute(path: '/owner/drivers',   builder: (_, _) => const DriversScreen()),
      GoRoute(
        path: '/owner/drivers/:id',
        builder: (_, state) => DriverDetailScreen(driverId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/owner/fleet/:id',
        builder: (_, state) => VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/owner/schedules',      builder: (_, _) => const SchedulesScreen()),
      GoRoute(path: '/owner/staff',          builder: (_, _) => const StaffScreen()),
      GoRoute(path: '/owner/reports',        builder: (_, _) => const ReportsScreen()),
      GoRoute(path: '/owner/stations',       builder: (_, _) => const StationsScreen()),
      GoRoute(path: '/owner/notifications',  builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/owner/campaigns',      builder: (_, _) => const CampaignSettingsScreen()),
      GoRoute(path: '/owner/setup',          builder: (_, _) => const SetupStepperScreen()),

      // ── Passenger: notification preferences ──────────────────────────────
      GoRoute(
        path: '/passenger/notification-settings',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
    ],
  );
});

class TransProApp extends ConsumerWidget {
  const TransProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale    = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'TransPro CI',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      darkTheme: appDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF05A1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus_rounded, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text('TransPro CI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
