import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/setup_progress.dart';
import '../../../core/theme/app_theme.dart';
import '../setup_progress_provider.dart';

/// Compact banner displayed at the top of the owner dashboard when setup < 100%.
/// Shows overall progress, milestone label and a CTA button.
class SetupProgressBanner extends ConsumerWidget {
  const SetupProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(setupProgressProvider);

    return progressAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (progress) {
        if (progress.isComplete) return const SizedBox.shrink();
        return _BannerCard(progress: progress);
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final SetupProgress progress;
  const _BannerCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final next = progress.nextStep;

    return GestureDetector(
      onTap: () => context.push('/owner/setup'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandOrange.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: brandOrange.withValues(alpha: 0.08), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title row
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: brandOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.rocket_launch_rounded, size: 16, color: brandOrange),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration en cours',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: brandDark),
                ),
                Text(
                  '${progress.overall}% • ${progress.completedCount}/${progress.totalCount} étapes',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: brandOrange, size: 20),
          ]),

          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.overall / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: brandOrange.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(brandOrange),
              ),
            ),
          ),

          // Next step
          if (next != null) ...[
            const SizedBox(height: 10),
            _NextStepChip(step: next),
          ],
        ]),
      ),
    );
  }
}

class _NextStepChip extends StatelessWidget {
  final SetupStep step;
  const _NextStepChip({required this.step});

  @override
  Widget build(BuildContext context) {
    final isBlocked = step.isBlocked;

    return Row(children: [
      Icon(
        isBlocked ? Icons.lock_outline_rounded : Icons.arrow_circle_right_outlined,
        size: 13,
        color: isBlocked ? Color(0xFFDC2626) : brandOrange,
      ),
      const SizedBox(width: 5),
      Expanded(child: Text(
        isBlocked
            ? 'Bloqué : ${step.blockedReason ?? step.title}'
            : 'Prochaine étape : ${step.title}',
        style: TextStyle(
          fontSize: 11,
          color: isBlocked ? const Color(0xFFDC2626) : context.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      )),
      if (!isBlocked && step.route != null)
        GestureDetector(
          onTap: () => context.push(step.route!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: brandOrange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              step.action ?? 'Commencer',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
    ]);
  }
}
