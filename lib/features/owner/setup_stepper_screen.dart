import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/setup_progress.dart';
import '../../core/theme/app_theme.dart';
import 'setup_progress_provider.dart';

class SetupStepperScreen extends ConsumerWidget {
  const SetupStepperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(setupProgressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          'Guide de démarrage',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: brandDark),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: brandDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: brandOrange)),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(setupProgressProvider)),
        data: (progress) => _StepperBody(progress: progress),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _StepperBody extends StatelessWidget {
  final SetupProgress progress;
  const _StepperBody({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(progress: progress),
          const SizedBox(height: 24),
          ...List.generate(progress.steps.length, (i) {
            final step = progress.steps[i];
            final isLast = i == progress.steps.length - 1;
            return _StepTile(step: step, index: i, isLast: isLast);
          }),
          const SizedBox(height: 16),
          if (progress.isComplete) const _CompletionCard(),
        ],
      ),
    );
  }
}

// ─── Progress Header ──────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final SetupProgress progress;
  const _ProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandOrange, Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: brandOrange.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(progress.milestoneEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.milestoneLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                ),
                Text(
                  '${progress.completedCount} / ${progress.totalCount} étapes terminées',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            )),
            _CircleProgress(value: progress.overall),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.overall / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.overall}% de configuration terminée',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Circle progress indicator ────────────────────────────────────────────────

class _CircleProgress extends StatelessWidget {
  final int value;
  const _CircleProgress({required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    height: 58,
    child: Stack(alignment: Alignment.center, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value / 100),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CircularProgressIndicator(
          value: v,
          strokeWidth: 5,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        ),
      ),
      Text(
        '$value%',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ]),
  );
}

// ─── Step tile ────────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final SetupStep step;
  final int index;
  final bool isLast;

  const _StepTile({required this.step, required this.index, required this.isLast});

  Color get _statusColor => switch (step.status) {
    SetupStepStatus.completed => const Color(0xFF16A34A),
    SetupStepStatus.blocked   => const Color(0xFFDC2626),
    SetupStepStatus.pending   => brandOrange,
  };

  Color get _bgColor => switch (step.status) {
    SetupStepStatus.completed => const Color(0xFFF0FDF4),
    SetupStepStatus.blocked   => const Color(0xFFFEF2F2),
    SetupStepStatus.pending   => brandLight,
  };

  IconData get _statusIcon => switch (step.status) {
    SetupStepStatus.completed => Icons.check_circle_rounded,
    SetupStepStatus.blocked   => Icons.lock_rounded,
    SetupStepStatus.pending   => Icons.radio_button_unchecked_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: step.isCompleted ? const Color(0xFF16A34A) : _bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: _statusColor, width: 2),
                ),
                child: Icon(_statusIcon, size: 16, color: step.isCompleted ? Colors.white : _statusColor),
              ),
              if (!isLast)
                Expanded(child: Container(
                  width: 2, margin: const EdgeInsets.symmetric(vertical: 4),
                  color: step.isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
                )),
            ]),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: _StepCard(step: step, statusColor: _statusColor, bgColor: _bgColor),
          )),
        ],
      ),
    );
  }
}

// ─── Step card content ────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final SetupStep step;
  final Color statusColor;
  final Color bgColor;

  const _StepCard({required this.step, required this.statusColor, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: step.isPending ? statusColor.withValues(alpha: 0.3) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + badge
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(_iconData(step.icon), size: 18, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            step.title,
            style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: step.isCompleted ? const Color(0xFF16A34A) : brandDark,
              decoration: step.isCompleted ? TextDecoration.none : null,
            ),
          )),
          _StatusBadge(step: step),
        ]),
        const SizedBox(height: 8),
        Text(step.description, style: TextStyle(fontSize: 12, color: context.textMuted, height: 1.4)),

        // Blocked explanation
        if (step.isBlocked && step.blockedReason != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                step.blockedReason!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.3),
              )),
            ]),
          ),
          if (step.blockedAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(step.blockedRoute!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(step.blockedAction!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],

        // Action button for pending steps
        if (step.isPending && step.route != null && step.action != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(step.route!),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: Text(step.action!),
              style: FilledButton.styleFrom(
                backgroundColor: brandOrange,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],

        // Completed confirmation
        if (step.isCompleted) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
            Text('Terminé', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }

  IconData _iconData(String name) => switch (name) {
    'business'          => Icons.business_rounded,
    'location_city'     => Icons.location_city_rounded,
    'directions_bus'    => Icons.directions_bus_rounded,
    'person'            => Icons.person_rounded,
    'alt_route'         => Icons.alt_route_rounded,
    'departure_board'   => Icons.departure_board_rounded,
    'confirmation_num'  => Icons.confirmation_num_rounded,
    'payments'          => Icons.payments_rounded,
    'point_of_sale'     => Icons.point_of_sale_rounded,
    _                   => Icons.check_circle_rounded,
  };
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final SetupStep step;
  const _StatusBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (step.status) {
      SetupStepStatus.completed => ('Terminé',   const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      SetupStepStatus.blocked   => ('Bloqué',    const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      SetupStepStatus.pending   => ('À faire',   brandOrange,             brandLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Completion card ──────────────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Text('🎉', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 16),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Système opérationnel !',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(height: 4),
            Text('Votre compagnie est prête à recevoir des réservations.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
          ],
        )),
      ]),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
      const SizedBox(height: 12),
      const Text('Impossible de charger la progression', style: TextStyle(color: Color(0xFF6B7280))),
      const SizedBox(height: 12),
      FilledButton(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: brandOrange),
        child: const Text('Réessayer')),
    ]),
  );
}
