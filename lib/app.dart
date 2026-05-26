import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
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
import 'features/agent/caisse_screen.dart';
import 'features/owner/owner_shell.dart';
import 'features/owner/dashboard_screen.dart';
import 'features/owner/drivers_screen.dart';
import 'features/owner/fleet_screen.dart';
import 'features/owner/reports_screen.dart';
import 'features/owner/routes_screen.dart';
import 'features/owner/schedules_screen.dart';
import 'features/owner/staff_screen.dart';
import 'features/owner/stations_screen.dart';
import 'features/owner/trips_screen.dart';
import 'features/owner/owner_profile_screen.dart';
import 'features/passenger/trip_tracking_screen.dart';
import 'features/passenger/payment_webview_screen.dart';
import 'features/passenger/payment_success_screen.dart';
import 'features/passenger/payment_error_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter _buildRouter(AuthState auth) {
  String initial;
  if (auth.isLoading) {
    initial = '/splash';
  } else if (!auth.isAuthenticated) {
    initial = '/login';
  } else if (auth.user!.isPassenger) {
    initial = '/passenger';
  } else if (auth.user!.isAgent) {
    initial = '/agent';
  } else if (auth.user!.isOwner) {
    initial = '/owner';
  } else {
    initial = '/login';
  }

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: initial,
    // Remap custom scheme deep links: transpro://track/ID → /track/ID
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'transpro' && uri.host == 'track') {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (id.isNotEmpty) return '/track/$id';
      }

      if (auth.isLoading) return '/splash';

      final authenticated = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/forgot-password');
      final isPinRoute = loc == '/pin-login' || loc == '/pin-setup';
      final isPublicRoute = loc.startsWith('/track/');

      if (!authenticated && !isAuthRoute && !isPublicRoute) return '/login';

      if (authenticated && !isPinRoute && !isPublicRoute) {
        // PIN gate: require verification before accessing the app
        if (auth.hasPinSet && !auth.pinVerified) return '/pin-login';
        // First login: no PIN set yet, redirect to setup
        if (!auth.hasPinSet) return '/pin-setup';
        // PIN verified — redirect away from auth screens to role home
        if (isAuthRoute) {
          if (auth.user!.isPassenger) return '/passenger';
          if (auth.user!.isAgent) return '/agent';
          if (auth.user!.isOwner) return '/owner';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',        builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/pin-setup',       builder: (_, __) => const PinSetupScreen()),
      GoRoute(path: '/pin-login',       builder: (_, __) => const PinLoginScreen()),

      // ── Passenger ─────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => PassengerShell(child: child),
        routes: [
          GoRoute(path: '/passenger', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/passenger/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/passenger/bookings', builder: (_, __) => const BookingsScreen()),
          GoRoute(path: '/passenger/profile', builder: (_, __) => const PassengerProfileScreen()),
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
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/passenger/payment/webview',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymentWebViewScreen(
            checkoutUrl: extra['checkoutUrl'] as String,
            bookingId: extra['bookingId'] as String,
          );
        },
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

      // ── Agent ─────────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => AgentShell(child: child),
        routes: [
          GoRoute(path: '/agent',          builder: (_, __) => const DeparturesScreen()),
          GoRoute(path: '/agent/scanner',  builder: (_, __) => const ScannerScreen()),
          GoRoute(path: '/agent/guichet',  builder: (_, __) => const GuichetScreen()),
          GoRoute(path: '/agent/caisse',   builder: (_, __) => const CaisseScreen()),
          GoRoute(path: '/agent/profile',  builder: (_, __) => const AgentProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/agent/manifest/:tripId',
        builder: (_, state) => ManifestScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/agent/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // ── Public trip tracking (no auth required) ───────────────────────────
      GoRoute(
        path: '/track/:tripId',
        builder: (_, state) => TripTrackingScreen(tripId: state.pathParameters['tripId']!),
      ),

      // ── Owner ─────────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => OwnerShell(child: child),
        routes: [
          GoRoute(path: '/owner',         builder: (_, __) => const OwnerDashboardScreen()),
          GoRoute(path: '/owner/trips',   builder: (_, __) => const OwnerTripsScreen()),
          GoRoute(path: '/owner/fleet',   builder: (_, __) => const FleetScreen()),
          GoRoute(path: '/owner/routes',  builder: (_, __) => const OwnerRoutesScreen()),
          GoRoute(path: '/owner/profile', builder: (_, __) => const OwnerProfileScreen()),
        ],
      ),
      GoRoute(path: '/owner/drivers',   builder: (_, __) => const DriversScreen()),
      GoRoute(path: '/owner/schedules', builder: (_, __) => const SchedulesScreen()),
      GoRoute(path: '/owner/staff',     builder: (_, __) => const StaffScreen()),
      GoRoute(path: '/owner/reports',   builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/owner/stations',       builder: (_, __) => const StationsScreen()),
      GoRoute(path: '/owner/notifications',  builder: (_, __) => const NotificationsScreen()),
    ],
  );
}

class TransProApp extends ConsumerWidget {
  const TransProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final router = _buildRouter(auth);
    return MaterialApp.router(
      title: 'TransPro CI',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
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
