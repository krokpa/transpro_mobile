import 'package:flutter/material.dart';

// ── Core shimmer animation ────────────────────────────────────────────────────

/// Wraps [child] in a sweeping gradient shimmer effect.
/// All grey boxes painted inside it animate in sync.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base  = dark ? const Color(0xFF252833) : const Color(0xFFE4E7ED);
    final shine = dark ? const Color(0xFF343848) : const Color(0xFFF2F4F7);

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, child) {
        final v = _ctrl.value * 4 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(v - 1, -0.3),
            end:   Alignment(v + 1,  0.3),
            colors: [base, shine, base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child!,
        );
      },
    );
  }
}

// ── Primitive shimmer block ────────────────────────────────────────────────────

/// A single opaque grey rectangle — used as a text/image placeholder.
/// Place inside a [Shimmer] so it animates.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2D3A) : const Color(0xFFD8DCE5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Skeleton tile shapes ──────────────────────────────────────────────────────

/// Generic list tile: circle + two text lines + trailing badge.
/// Matches notification, transaction, driver, staff, etc.
class ShimmerListTile extends StatelessWidget {
  final EdgeInsets? padding;
  const ShimmerListTile({super.key, this.padding});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const ShimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ShimmerBox(height: 14, radius: 7),
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.62,
                child: const ShimmerBox(height: 11, radius: 6),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          const ShimmerBox(width: 48, height: 20, radius: 10),
        ]),
      );
}

/// Trip / departure card skeleton.
/// Matches the tall card with route, time, seats, and action button.
class ShimmerTripCard extends StatelessWidget {
  const ShimmerTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2130) : const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const ShimmerBox(width: 38, height: 38, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ShimmerBox(height: 15, radius: 7),
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.55,
                child: const ShimmerBox(height: 11, radius: 6),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          const ShimmerBox(width: 60, height: 24, radius: 12),
        ]),
        const SizedBox(height: 12),
        const ShimmerBox(height: 1, radius: 0),
        const SizedBox(height: 10),
        Row(children: const [
          ShimmerBox(width: 70, height: 11, radius: 6),
          SizedBox(width: 12),
          ShimmerBox(width: 55, height: 11, radius: 6),
          Spacer(),
          ShimmerBox(width: 80, height: 28, radius: 8),
        ]),
      ]),
    );
  }
}

/// Booking card skeleton (date block | divider | route | amount).
class ShimmerBookingCard extends StatelessWidget {
  const ShimmerBookingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2130) : const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Column(children: const [
          ShimmerBox(width: 28, height: 20, radius: 4),
          SizedBox(height: 4),
          ShimmerBox(width: 24, height: 11, radius: 4),
        ]),
        const SizedBox(width: 14),
        Container(
            width: 1,
            height: 48,
            color: dark
                ? const Color(0xFF3A3F52)
                : const Color(0xFFCDD1D9)),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ShimmerBox(height: 14, radius: 7),
            const SizedBox(height: 6),
            FractionallySizedBox(
              widthFactor: 0.65,
              child: const ShimmerBox(height: 11, radius: 6),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
          ShimmerBox(width: 60, height: 14, radius: 6),
          SizedBox(height: 5),
          ShimmerBox(width: 48, height: 20, radius: 10),
        ]),
      ]),
    );
  }
}

/// Parcel / package row skeleton.
class ShimmerParcelTile extends StatelessWidget {
  const ShimmerParcelTile({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const ShimmerBox(width: 42, height: 42, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ShimmerBox(width: 100, height: 13, radius: 6),
              const SizedBox(height: 5),
              const ShimmerBox(height: 11, radius: 6),
              const SizedBox(height: 4),
              const ShimmerBox(width: 70, height: 10, radius: 5),
            ]),
          ),
          const SizedBox(width: 8),
          const ShimmerBox(width: 56, height: 22, radius: 11),
        ]),
      );
}

/// Manifest entry skeleton (passenger name + ticket chips).
class ShimmerManifestTile extends StatelessWidget {
  const ShimmerManifestTile({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const ShimmerBox(width: 40, height: 40, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(height: 14, radius: 7),
                    const SizedBox(height: 5),
                    const ShimmerBox(width: 90, height: 11, radius: 6),
                  ]),
            ),
            const ShimmerBox(width: 44, height: 22, radius: 11),
          ]),
          const SizedBox(height: 10),
          Row(children: const [
            ShimmerBox(width: 40, height: 32, radius: 8),
            SizedBox(width: 8),
            ShimmerBox(width: 40, height: 32, radius: 8),
            SizedBox(width: 8),
            ShimmerBox(width: 40, height: 32, radius: 8),
          ]),
        ]),
      );
}

/// Company chip skeleton (logo circle + name).
class ShimmerCompanyChip extends StatelessWidget {
  const ShimmerCompanyChip({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2130) : const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        ShimmerBox(width: 48, height: 48, radius: 24),
        SizedBox(height: 8),
        ShimmerBox(height: 12, radius: 6),
        SizedBox(height: 4),
        ShimmerBox(width: 60, height: 10, radius: 5),
      ]),
    );
  }
}

// ── Page-level shimmer builders ───────────────────────────────────────────────

/// Factory of ready-made shimmer loading states for common page types.
class AppShimmer {
  AppShimmer._();

  /// Generic scrollable list tiles (notifications, transactions, drivers…)
  static Widget listTiles({int count = 5}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: List.generate(
              count,
              (_) => const Column(children: [
                ShimmerListTile(),
                Divider(height: 1, indent: 72, endIndent: 16),
              ]),
            ),
          ),
        ),
      );

  /// Trip / departure cards (agent departures, owner trips, schedules)
  static Widget tripCards({int count = 4}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            children: List.generate(count, (_) => const ShimmerTripCard()),
          ),
        ),
      );

  /// Booking cards (passenger bookings list)
  static Widget bookingCards({int count = 5}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(count, (_) => const ShimmerBookingCard()),
          ),
        ),
      );

  /// Parcel rows (my parcels, agent parcels)
  static Widget parcelTiles({int count = 5}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: List.generate(
              count,
              (_) => const Column(children: [
                ShimmerParcelTile(),
                Divider(height: 1, indent: 70, endIndent: 16),
              ]),
            ),
          ),
        ),
      );

  /// Manifest passenger rows
  static Widget manifestTiles({int count = 5}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: List.generate(
              count,
              (_) => const Column(children: [
                ShimmerManifestTile(),
                Divider(height: 1, indent: 16, endIndent: 16),
              ]),
            ),
          ),
        ),
      );

  /// Company grid/list
  static Widget companyChips({int count = 6}) => Shimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(count, (_) => const ShimmerCompanyChip()),
          ),
        ),
      );
}
