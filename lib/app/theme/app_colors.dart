import 'package:flutter/material.dart';

/// ХУВААЛЦ brand color tokens.
///
/// Two closed palettes — light and dark — per the product design spec.
/// Never reference raw hex values in feature code; always go through
/// [AppColors] (or the extension resolved from [Theme.of(context)]) so a
/// future palette change is a one-file edit.
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.accentPressed,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.border,
    required this.onPrimary,
    required this.onSurface,
  });

  final Color background;
  final Color surface;

  /// A step lighter than [surface] — for content that should read as
  /// *lifted above* the base surface (bottom sheets, dialogs, popover
  /// menus) rather than sitting flush with it. In light mode this is the
  /// same white as [surface] (there's no headroom to go lighter, and this
  /// app uses shadows, not extra brightness, for light-mode elevation);
  /// in dark mode it's a distinctly lighter charcoal, giving dark
  /// surfaces the layered depth 2026's "dark-mode-as-primary-surface"
  /// trend calls for instead of one flat near-black slab.
  final Color surfaceRaised;

  final Color primary;
  final Color secondary;
  final Color accent;

  /// Pressed/active-press state of [accent] — a touch darker, for button
  /// press overlays and other momentary "being pressed" feedback. Not a
  /// second brand color; [accent] is still the one CTA/active-state hue,
  /// this is just its depressed variant.
  final Color accentPressed;

  /// A pale tint of [accent] for *backgrounds* behind active/selected
  /// content (e.g. a selected filter chip) where the full solid [accent]
  /// would be too loud — keeps the "yellow = action/active only" rule
  /// from section 2026's design spec legible even for low-emphasis active
  /// states, instead of reaching for gray.
  final Color accentSoft;

  final Color success;
  final Color warning;
  final Color danger;
  final Color border;

  /// Text/icon color to place on top of [primary].
  final Color onPrimary;

  /// Default text/icon color to place on top of [surface] / [background].
  final Color onSurface;

  // `accent` in both palettes below was switched from the original blue
  // (light 0xFF2563EB / dark 0xFF5B8CFF) to a warm amber/gold family —
  // approved via a color-scheme mockup (see the design canvas shared in
  // chat) after the app was reported to look too plain/monochrome. Same
  // relationship as before: dark mode gets a *lighter/brighter* tint of
  // the hue than light mode, since a saturated-but-darker tone (right for
  // sitting on a near-white background) reads muddy on a near-black one —
  // 0xFFFBBF24 is the brighter amber-400 tint of light mode's 0xFFEAB308
  // amber-500, the same relationship the old blue pair had.
  // Light palette values below match the 2026 design-spec's exact hex
  // values (shared in chat: primary #FBBF0A, pressed #E9AE00, soft yellow
  // #FFF6D8, black #171717, secondary text #737373, border #EAEAEA,
  // background #FAFAF8) — the spec was light-mode-first, so dark mode
  // keeps its prior palette (already amber-themed) rather than guessing
  // dark equivalents the user hasn't reviewed.
  static const AppColors light = AppColors(
    background: Color(0xFFFAFAF8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    primary: Color(0xFF171717),
    secondary: Color(0xFF737373),
    accent: Color(0xFFFBBF0A),
    accentPressed: Color(0xFFE9AE00),
    accentSoft: Color(0xFFFFF6D8),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDC2626),
    border: Color(0xFFEAEAEA),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF171717),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF09090B),
    surface: Color(0xFF151517),
    surfaceRaised: Color(0xFF1E1E21),
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFA1A1AA),
    accent: Color(0xFFFBBF24),
    accentPressed: Color(0xFFE0A812),
    accentSoft: Color(0xFF3A2E05),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    border: Color(0xFF27272A),
    onPrimary: Color(0xFF09090B),
    onSurface: Color(0xFFFFFFFF),
  );
}

/// Makes [AppColors] reachable as `Theme.of(context).extension<AppColorsExtension>()!.colors`
/// so widgets automatically follow light/dark/system mode without manual checks.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension(this.colors);

  final AppColors colors;

  @override
  AppColorsExtension copyWith({AppColors? colors}) {
    return AppColorsExtension(colors ?? this.colors);
  }

  @override
  AppColorsExtension lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      AppColors(
        background: Color.lerp(colors.background, other.colors.background, t)!,
        surface: Color.lerp(colors.surface, other.colors.surface, t)!,
        surfaceRaised: Color.lerp(colors.surfaceRaised, other.colors.surfaceRaised, t)!,
        primary: Color.lerp(colors.primary, other.colors.primary, t)!,
        secondary: Color.lerp(colors.secondary, other.colors.secondary, t)!,
        accent: Color.lerp(colors.accent, other.colors.accent, t)!,
        accentPressed: Color.lerp(colors.accentPressed, other.colors.accentPressed, t)!,
        accentSoft: Color.lerp(colors.accentSoft, other.colors.accentSoft, t)!,
        success: Color.lerp(colors.success, other.colors.success, t)!,
        warning: Color.lerp(colors.warning, other.colors.warning, t)!,
        danger: Color.lerp(colors.danger, other.colors.danger, t)!,
        border: Color.lerp(colors.border, other.colors.border, t)!,
        onPrimary: Color.lerp(colors.onPrimary, other.colors.onPrimary, t)!,
        onSurface: Color.lerp(colors.onSurface, other.colors.onSurface, t)!,
      ),
    );
  }
}

/// Convenience accessor: `context.colors.accent`.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColorsExtension>()?.colors ?? AppColors.light;
}
