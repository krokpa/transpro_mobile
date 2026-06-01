import 'package:flutter/material.dart';

/// One-shot fade + upward-slide entrance animation.
///
/// Triggers once when the widget is first inserted into the tree.
/// Subsequent rebuilds do NOT restart the animation.
/// Respects [MediaQueryData.disableAnimations] for accessibility.
class FadeSlideIn extends StatefulWidget {
  final Widget child;

  /// How long to wait before starting the animation (for stagger effects).
  final Duration delay;

  /// Total animation duration.
  final Duration duration;

  /// Starting offset expressed as a fraction of the widget size.
  /// Default (0, 0.06) = slide up 6 % of height.
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 280),
    this.beginOffset = const Offset(0.0, 0.06),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
