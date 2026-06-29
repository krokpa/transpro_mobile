import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_constants.dart';

/// État de connectivité temps réel de l'application.
/// - [online]        : interface réseau ET API joignable.
/// - [offline]       : aucune interface réseau (avion, pas de Wi-Fi/données).
/// - [noInternet]    : interface présente mais aucun accès (portail captif,
///                     Wi-Fi sans internet, API injoignable).
enum ConnectivityStatus { online, offline, noInternet }

extension ConnectivityStatusX on ConnectivityStatus {
  bool get isOnline => this == ConnectivityStatus.online;
}

/// Détecteur de connectivité : combine les changements d'interface
/// ([connectivity_plus], instantanés) avec un *probe* HTTP réel vers l'API
/// (`/health/ping`) pour confirmer une joignabilité effective. Re-vérifie
/// périodiquement tant qu'on n'est pas en ligne (heartbeat), sans polling
/// inutile une fois connecté.
class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  final Connectivity _connectivity = Connectivity();
  late final Dio _probe;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  Timer? _heartbeat;

  static const _probeTimeout = Duration(seconds: 3);
  static const _debounceDelay = Duration(milliseconds: 400);
  static const _heartbeatInterval = Duration(seconds: 20);

  @override
  ConnectivityStatus build() {
    _probe = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: _probeTimeout,
      receiveTimeout: _probeTimeout,
    ));
    _sub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
      _heartbeat?.cancel();
      _probe.close(force: true);
    });
    // Vérification initiale (asynchrone) ; on démarre optimiste.
    _init();
    return ConnectivityStatus.online;
  }

  Future<void> _init() async {
    try {
      _onConnectivityChanged(await _connectivity.checkConnectivity());
    } catch (_) {
      _probeNow();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasInterface =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!hasInterface) {
      _set(ConnectivityStatus.offline);
      return;
    }
    // Interface présente → on confirme par un probe réel (débounce anti-flicker
    // lors des transitions Wi-Fi ↔ données mobiles).
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _probeNow);
  }

  Future<void> _probeNow() async {
    try {
      await _probe.get('/health/ping');
      _set(ConnectivityStatus.online);
    } catch (_) {
      // Interface up mais API/internet injoignable.
      _set(ConnectivityStatus.noInternet);
    }
  }

  void _set(ConnectivityStatus next) {
    if (state != next) {
      state = next;
      if (kDebugMode) debugPrint('[Connectivity] → $next');
    }
    _manageHeartbeat();
  }

  void _manageHeartbeat() {
    if (state.isOnline) {
      _heartbeat?.cancel();
      _heartbeat = null;
    } else {
      _heartbeat ??= Timer.periodic(_heartbeatInterval, (_) => _probeNow());
    }
  }

  /// Force une re-vérification immédiate (ex. action utilisateur « Réessayer »
  /// ou hook d'échec réseau du client dio en Phase 2).
  Future<void> recheck() => _probeNow();
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
        ConnectivityNotifier.new);

/// Raccourci booléen pour l'UI/logique métier.
final isOnlineProvider =
    Provider<bool>((ref) => ref.watch(connectivityProvider).isOnline);
