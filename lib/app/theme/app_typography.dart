import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single-family type scale: Manrope (geometric, warm, full Mongolian
/// Cyrillic coverage) for everything — UI chrome, body copy, and headings
/// alike, per the 2026 design spec's font system. Replaces the prior
/// Inter + PT Serif pairing (the serif hero-heading accent on
/// [displayLarge]/[displayMedium] was dropped along with it, in favor of
/// one consistent, weight-driven type system matching the spec's
/// "clean, warm, minimal marketplace" direction).
///
/// Fetched via `google_fonts` and cached on first use.
///
/// Keep this the single source of truth for text styles; features should
/// pull from `Theme.of(context).textTheme`, not construct [TextStyle]
/// literals inline.
class AppTypography {
  const AppTypography._();

  /// Resolved family name for the handful of places that need a bare
  /// `fontFamily` string rather than a full [TextStyle] — chiefly
  /// `ThemeData.fontFamily`, the fallback used by any text that isn't
  /// styled from [textTheme]. `google_fonts` downloads and caches the
  /// font on first use and silently falls back to the platform default
  /// if that fetch ever fails, so referencing it here never blocks
  /// rendering.
  static String? get fontFamily => GoogleFonts.manrope().fontFamily;

  static TextTheme textTheme(Color color) {
    final TextTheme base = TextTheme(
      // Editorial display heading — onboarding, hero copy.
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );

    // Applies Manrope's fontFamily/fontFamilyFallback to every style above
    // while preserving the sizes/weights/heights/letter-spacing/color
    // already set on each — the one line that turns this from a
    // system-font placeholder into a real, shipped type system.
    return GoogleFonts.manropeTextTheme(base);
  }
}
