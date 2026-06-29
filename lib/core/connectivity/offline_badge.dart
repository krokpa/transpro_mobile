import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'connectivity_provider.dart';

/// Bandeau « données hors-ligne » réutilisable, à placer en tête d'un écran qui
/// peut servir des données issues du cache. Affichage :
///  • si [offline] est fourni (provider sachant qu'il sert du cache) → ce flag ;
///  • sinon → s'appuie sur l'état de connectivité global ([isOnlineProvider]).
/// Se réduit à zéro hauteur quand en ligne.
class OfflineBadge extends ConsumerWidget {
  final bool? offline;
  final String? message;
  const OfflineBadge({super.key, this.offline, this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = offline ?? !ref.watch(isOnlineProvider);
    if (!isOffline) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF9C3),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFCA8A04)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message ?? l10n.offlineDataNotice,
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}
