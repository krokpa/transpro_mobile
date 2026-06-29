import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../connectivity/connectivity_provider.dart';
import '../../l10n/app_localizations.dart';

/// Vue d'erreur réutilisable et conviviale pour les `error:` des providers.
/// - Ne montre JAMAIS l'exception technique brute.
/// - Si hors-ligne → message « Aucun accès à internet » + icône Wi-Fi.
/// - Sinon → message lisible via [apiErrorMessage].
/// - Bouton « Réessayer » optionnel ([onRetry]).
class AppErrorView extends ConsumerWidget {
  final Object error;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = !ref.watch(isOnlineProvider);
    final message = offline ? l10n.connectivityNoInternet : apiErrorMessage(error);
    final color = offline ? const Color(0xFFB45309) : const Color(0xFFDC2626);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 44,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
