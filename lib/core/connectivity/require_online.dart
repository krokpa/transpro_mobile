import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'connectivity_provider.dart';

/// Garde de connectivité pour les actions de modification (réservation,
/// paiement, vente guichet, scan…). Renvoie `true` si en ligne ; sinon affiche
/// un message et renvoie `false` — l'appelant interrompt alors l'action.
///
/// Usage :
/// ```dart
/// if (!requireOnline(context, ref)) return;
/// await dio.post(...);
/// ```
bool requireOnline(BuildContext context, WidgetRef ref) {
  if (ref.read(isOnlineProvider)) return true;
  // Re-vérifie en arrière-plan (le statut peut être périmé entre deux probes).
  ref.read(connectivityProvider.notifier).recheck();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).connectivityActionOffline),
      backgroundColor: const Color(0xFFB91C1C),
      behavior: SnackBarBehavior.floating,
    ),
  );
  return false;
}
