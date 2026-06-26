import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/settings/settings_cache.dart';
import '../../core/theme/app_theme.dart';

// ── Modèle d'une slide ────────────────────────────────────────────────────────

class WalkthroughSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const WalkthroughSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

// ── Contenu par rôle ──────────────────────────────────────────────────────────

const kDriverSlides = [
  WalkthroughSlide(
    icon: Icons.directions_bus_rounded,
    color: Color(0xFFF97316),
    title: 'Vos voyages du jour',
    body: 'Consultez en un coup d\'œil tous les voyages qui vous sont assignés aujourd\'hui et leurs horaires.',
  ),
  WalkthroughSlide(
    icon: Icons.radio_button_checked_rounded,
    color: Color(0xFF22C55E),
    title: 'Gérez votre disponibilité',
    body: 'Indiquez si vous êtes disponible ou non. Votre compagnie peut ainsi planifier les affectations en temps réel.',
  ),
  WalkthroughSlide(
    icon: Icons.gps_fixed_rounded,
    color: Color(0xFF3B82F6),
    title: 'Suivi GPS en direct',
    body: 'Activez le partage de position pendant vos voyages. Les passagers peuvent suivre le bus en temps réel sur la carte.',
  ),
  WalkthroughSlide(
    icon: Icons.star_rounded,
    color: Color(0xFFF59E0B),
    title: 'Évaluations et absences',
    body: 'Consultez vos évaluations passagers et déclarez vos absences directement depuis votre profil.',
  ),
];

const kOwnerSlides = [
  WalkthroughSlide(
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF6366F1),
    title: 'Tableau de bord',
    body: 'Suivez en temps réel les performances de votre compagnie : revenus, voyages, passagers et taux d\'occupation.',
  ),
  WalkthroughSlide(
    icon: Icons.departure_board_rounded,
    color: Color(0xFF0EA5E9),
    title: 'Gérez vos voyages',
    body: 'Planifiez, modifiez et suivez tous vos voyages. Consultez les réservations et l\'occupation de chaque trajet.',
  ),
  WalkthroughSlide(
    icon: Icons.directions_bus_filled_rounded,
    color: Color(0xFF10B981),
    title: 'Flotte et chauffeurs',
    body: 'Gérez votre parc de véhicules et vos chauffeurs. Suivez les permis, évaluations et disponibilités.',
  ),
  WalkthroughSlide(
    icon: Icons.point_of_sale_rounded,
    color: Color(0xFFF97316),
    title: 'Billetterie & colis',
    body: 'Vendez des billets au guichet, gérez les colis et imprimez les tickets directement depuis le tableau de bord.',
  ),
];

const kAgentSlides = [
  WalkthroughSlide(
    icon: Icons.departure_board_rounded,
    color: Color(0xFF10B981),
    title: 'Gestion des départs',
    body: 'Consultez tous les voyages au départ de votre gare, leur état d\'embarquement et les passagers inscrits.',
  ),
  WalkthroughSlide(
    icon: Icons.point_of_sale_rounded,
    color: Color(0xFF0EA5E9),
    title: 'Vente au guichet',
    body: 'Créez des réservations pour les passagers sur place, choisissez leur siège et imprimez le billet en un clic.',
  ),
  WalkthroughSlide(
    icon: Icons.qr_code_scanner_rounded,
    color: Color(0xFF8B5CF6),
    title: 'Scanner de billets',
    body: 'Validez les billets des passagers à l\'embarquement en scannant leur QR code. Gérez les listes de manifeste.',
  ),
  WalkthroughSlide(
    icon: Icons.bar_chart_rounded,
    color: Color(0xFFF59E0B),
    title: 'Caisse et rapports',
    body: 'Suivez les encaissements de votre gare et consultez les rapports de vente journaliers et hebdomadaires.',
  ),
];

// ── Écran générique ───────────────────────────────────────────────────────────

class WalkthroughScreen extends StatefulWidget {
  final String roleKey;
  final String homeRoute;
  final List<WalkthroughSlide> slides;

  const WalkthroughScreen({
    super.key,
    required this.roleKey,
    required this.homeRoute,
    required this.slides,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SettingsCache.markWalkthroughDone(widget.roleKey);
    if (mounted) context.go(widget.homeRoute);
  }

  void _next() {
    if (_page < widget.slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_page > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide  = widget.slides[_page];
    final isLast = _page == widget.slides.length - 1;
    final isFirst = _page == 0;

    return Scaffold(
      backgroundColor: context.cardBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── Slides ──────────────────────────────────────────────────────
            PageView.builder(
              controller: _controller,
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _SlideView(slide: widget.slides[i]),
            ),

            // ── Bouton passer ────────────────────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: context.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Passer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),

            // ── Barre de navigation bas ──────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicateurs de progression
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.slides.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? slide.color : context.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // Boutons Précédent / Suivant
                      Row(
                        children: [
                          if (!isFirst)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _prev,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: slide.color,
                                  side: BorderSide(color: slide.color.withValues(alpha: 0.4)),
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          if (!isFirst) const SizedBox(width: 12),
                          Expanded(
                            flex: isFirst ? 1 : 1,
                            child: ElevatedButton(
                              onPressed: _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: slide.color,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                isLast ? 'Commencer' : 'Suivant',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide individuelle ────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final WalkthroughSlide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        // Zone illustration
        SizedBox(
          height: size.height * 0.52,
          width: double.infinity,
          child: Stack(
            children: [
              // Fond dégradé
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      slide.color.withValues(alpha: 0.13),
                      slide.color.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Cercles concentriques
              Center(
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.14),
                  ),
                ),
              ),
              // Icône principale
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.18),
                    boxShadow: [
                      BoxShadow(
                        color: slide.color.withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(slide.icon, size: 52, color: slide.color),
                ),
              ),
            ],
          ),
        ),

        // Texte
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 0),
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
              const SizedBox(height: 14),
              Text(
                slide.body,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.65,
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
