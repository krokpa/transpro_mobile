import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/settings/settings_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slideColors = [
    Color(0xFF3B82F6),
    brandOrange,
    Color(0xFF10B981),
  ];

  static const _slideIcons = [
    Icons.search_rounded,
    Icons.event_seat_rounded,
    Icons.phone_android_rounded,
  ];

  Future<void> _finish() async {
    await SettingsCache.markOnboardingDone();
    if (mounted) context.go('/passenger');
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  List<_SlideData> _buildSlides(AppLocalizations l10n) => [
    _SlideData(icon: _slideIcons[0], color: _slideColors[0],
        title: l10n.onboarding1Title, body: l10n.onboarding1Body),
    _SlideData(icon: _slideIcons[1], color: _slideColors[1],
        title: l10n.onboarding2Title, body: l10n.onboarding2Body),
    _SlideData(icon: _slideIcons[2], color: _slideColors[2],
        title: l10n.onboarding3Title, body: l10n.onboarding3Body),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context);
    final slides = _buildSlides(l10n);
    final isLast = _page == slides.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideView(slide: slides[i]),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.onboardingSkip,
                      style: TextStyle(color: context.textMuted)),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? slides[i].color
                                : context.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: slides[_page].color,
                        ),
                        child: Text(isLast ? l10n.onboardingStart : l10n.onboardingNext),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _SlideData({required this.icon, required this.color, required this.title, required this.body});
}

class _SlideView extends StatelessWidget {
  final _SlideData slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        SizedBox(
          height: size.height * 0.55,
          width: double.infinity,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      slide.color.withValues(alpha: 0.15),
                      slide.color.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.18),
                  ),
                  child: Icon(slide.icon, size: 64, color: slide.color),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Column(
            children: [
              Text(
                slide.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                slide.body,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
