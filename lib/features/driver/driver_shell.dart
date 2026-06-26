import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/space_theme.dart';

class DriverShell extends ConsumerWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  static const _tabs = [
    ('/driver',          Icons.dashboard_outlined,       Icons.dashboard_rounded,       'Accueil'),
    ('/driver/trips',    Icons.departure_board_outlined, Icons.departure_board_rounded, 'Voyages'),
    ('/driver/schedule', Icons.calendar_month_outlined,  Icons.calendar_month_rounded,  'Planning'),
    ('/driver/profile',  Icons.person_outline_rounded,   Icons.person_rounded,          'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    int current = 0;
    int bestLen = -1;
    for (int i = 0; i < _tabs.length; i++) {
      final path = _tabs[i].$1;
      if (location == path || location.startsWith('$path/')) {
        if (path.length > bestLen) { bestLen = path.length; current = i; }
      }
    }

    return SpaceTheme.wrap(
      context: context,
      colors: kDriverColors,
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (i) => context.go(_tabs[i].$1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _tabs.map((t) => NavigationDestination(
            icon: Icon(t.$2),
            selectedIcon: Icon(t.$3),
            label: t.$4,
          )).toList(),
        ),
      ),
    );
  }
}
