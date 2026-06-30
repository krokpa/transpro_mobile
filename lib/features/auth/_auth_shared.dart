import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/branding/branding_provider.dart';
import '../../core/theme/app_theme.dart';

// ── Background + dot grid ──────────────────────────────────────────────────────

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C1425), Color(0xFF1A2744)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
        Positioned(
          top: -90, right: -90,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandOrange.withValues(alpha: 0.09),
            ),
          ),
        ),
        Positioned(
          bottom: -60, left: -60,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandOrange.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Logo block ─────────────────────────────────────────────────────────────────

class AuthLogoBlock extends ConsumerWidget {
  final bool compact;
  const AuthLogoBlock({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final size = compact ? 72.0 : 96.0;
    final radius = compact ? 20.0 : 26.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFFC0532A).withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            // Logo de marque distant si configuré, sinon l'asset embarqué.
            child: branding.logoUrl != null
                ? Image.network(
                    branding.logoUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/images/transpro-logo.png',
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/images/transpro-logo.png',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          branding.appName,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 22 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          branding.tagline,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      ],
    );
  }
}

// ── Drag handle ────────────────────────────────────────────────────────────────

class AuthDragHandle extends StatelessWidget {
  const AuthDragHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: context.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ── Error banner ───────────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13.5))),
    ]),
  );
}

// ── Social login buttons ──────────────────────────────────────────────────────

class SocialBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;
  const SocialBtn({super.key, required this.onTap, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon,
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
      ]),
    ),
  );
}

class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18, height: 18,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(18, 18), painter: _GoogleQuadrantsPainter()),
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: context.cardBg, shape: BoxShape.circle),
      ),
    ]),
  );
}

class _GoogleQuadrantsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    for (int i = 0; i < 4; i++) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: r), -1.5708 + i * 1.5708, 1.5708, false)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class FacebookIcon extends StatelessWidget {
  const FacebookIcon({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 18, height: 18,
    decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
    alignment: Alignment.center,
    child: const Text('f',
      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1.1)),
  );
}

// ── Shared error extractor ────────────────────────────────────────────────────

String extractAuthError(dynamic e) {
  try {
    final data = (e as dynamic).response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      if (msg is String && msg.isNotEmpty) return msg;
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
    }
  } catch (_) {}
  return 'Une erreur est survenue';
}
