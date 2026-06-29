import 'package:flutter/material.dart';

// ── Palette par espace ─────────────────────────────────────────────────────────
// Modifier uniquement ces 4 constantes pour changer les couleurs de chaque espace.

class SpaceColors {
  final Color primary;
  final Color light; // fond subtil (pills, indicateurs)

  const SpaceColors({required this.primary, required this.light});
}

// ── Palettes d'espace — runtime (configurables par l'admin via la marque) ─────
// Non-const : mises à jour par [applyBrandSpaces] quand la marque est résolue.
// Le `light` (fond subtil) est dérivé automatiquement de la couleur d'espace.

SpaceColors kPassengerColors = const SpaceColors(
  primary: Color(0xFF0EA5E9), light: Color(0xFFE0F2FE)); // sky

SpaceColors kDriverColors = const SpaceColors(
  primary: Color(0xFFF97316), light: Color(0xFFFFF7ED)); // orange

SpaceColors kOwnerColors = const SpaceColors(
  primary: Color(0xFF6366F1), light: Color(0xFFEEF2FF)); // indigo

SpaceColors kAgentColors = const SpaceColors(
  primary: Color(0xFF10B981), light: Color(0xFFECFDF5)); // emerald

/// Teinte claire dérivée d'une couleur d'espace (fond des pills/indicateurs).
Color _spaceLight(Color c) => Color.lerp(c, Colors.white, 0.88)!;

/// Applique les couleurs d'espace configurées (admin). À appeler au démarrage
/// et à chaque rafraîchissement de la marque.
void applyBrandSpaces({
  required Color passenger,
  required Color agent,
  required Color owner,
  required Color driver,
}) {
  kPassengerColors = SpaceColors(primary: passenger, light: _spaceLight(passenger));
  kAgentColors     = SpaceColors(primary: agent,     light: _spaceLight(agent));
  kOwnerColors     = SpaceColors(primary: owner,     light: _spaceLight(owner));
  kDriverColors    = SpaceColors(primary: driver,    light: _spaceLight(driver));
}

// ── InheritedWidget — donne accès à context.spacePrimary dans toute la tree ───

class SpaceTheme extends InheritedWidget {
  final SpaceColors colors;

  const SpaceTheme({super.key, required this.colors, required super.child});

  static SpaceColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpaceTheme>()?.colors
      ?? kDriverColors;

  /// Wraps [child] avec SpaceTheme + Theme.copyWith pour que toute la subtree
  /// utilise automatiquement les bonnes couleurs (NavigationBar, boutons, inputs).
  static Widget wrap({
    required BuildContext context,
    required SpaceColors colors,
    required Widget child,
  }) {
    return SpaceTheme(
      colors: colors,
      child: Theme(
        data: _applyToTheme(Theme.of(context), colors),
        child: child,
      ),
    );
  }

  @override
  bool updateShouldNotify(SpaceTheme old) => colors.primary != old.colors.primary;
}

// ── Application de la palette sur un ThemeData ─────────────────────────────────

ThemeData _applyToTheme(ThemeData base, SpaceColors c) {
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary:          c.primary,
      primaryContainer: c.light,
      onPrimary:        Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: c.light,
      iconTheme: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? IconThemeData(color: c.primary, size: 24)
              : const IconThemeData(color: Color(0xFF94A3B8), size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)
              : const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: c.light,
    ),
  );
}
