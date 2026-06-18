import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Full-screen blocker displayed when a prerequisite is missing.
/// Shows a friendly explanation and a CTA button leading to the prerequisite.
class PrerequisiteBlockedScreen extends StatelessWidget {
  final String title;
  final String message;
  final String ctaLabel;
  final String ctaRoute;
  final IconData icon;

  const PrerequisiteBlockedScreen({
    super.key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.ctaRoute,
    this.icon = Icons.lock_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: const Color(0xFFDC2626)),
            ),
            const SizedBox(height: 24),
            Text(
              'Prérequis manquant',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: brandDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: context.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(ctaRoute),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(ctaLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: brandOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push('/owner/setup'),
              child: const Text('Voir le guide de démarrage',
                style: TextStyle(color: brandOrange, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}
