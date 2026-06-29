import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'connectivity_provider.dart';

/// Enveloppe l'application entière (via `MaterialApp.builder`) et superpose un
/// bandeau de connectivité temps réel :
///  • hors-ligne / pas d'accès → bandeau persistant (rouge atténué) ;
///  • retour en ligne → bandeau transitoire (vert) qui disparaît après 2 s.
///
/// Placé en haut (sous la barre d'état) pour ne jamais masquer la
/// NavigationBar présente en bas de tous les espaces.
class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _showRestored = false;
  Timer? _restoreTimer;

  @override
  void dispose() {
    _restoreTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityStatus>(connectivityProvider, (prev, next) {
      final recovered = prev != null && !prev.isOnline && next.isOnline;
      if (recovered) {
        setState(() => _showRestored = true);
        _restoreTimer?.cancel();
        _restoreTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showRestored = false);
        });
      }
    });

    final status  = ref.watch(connectivityProvider);
    final offline = !status.isOnline;
    final visible = offline || _showRestored;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _Bar(status: status, restored: !offline && _showRestored),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final ConnectivityStatus status;
  final bool restored;
  const _Bar({required this.status, required this.restored});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (Color bg, IconData icon, String label) = restored
        ? (const Color(0xFF16A34A), Icons.wifi_rounded, l10n.connectivityRestored)
        : switch (status) {
            ConnectivityStatus.offline =>
              (const Color(0xFFB91C1C), Icons.wifi_off_rounded, l10n.connectivityOffline),
            ConnectivityStatus.noInternet =>
              (const Color(0xFFB45309), Icons.signal_wifi_statusbar_connected_no_internet_4_rounded, l10n.connectivityNoInternet),
            ConnectivityStatus.online =>
              (const Color(0xFF16A34A), Icons.wifi_rounded, l10n.connectivityRestored),
          };

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: bg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
