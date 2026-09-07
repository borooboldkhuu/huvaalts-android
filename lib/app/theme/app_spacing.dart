import 'package:flutter/animation.dart' show Curve, Curves;

/// Spacing scale used across the app. Widgets should compose paddings and
/// gaps from these tokens instead of hardcoding numbers, so the whole app's
/// density can be tuned from one place.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double giant = 64;
}

/// Corner radius scale — rounded cards, not pill-everything.
///
/// 2026 refresh: rounder, more "organic" corners across the board (the
/// Material 3 Expressive shape direction) — every value below is a touch
/// softer than the original scale. Because every card/button/sheet/input
/// shape in `AppTheme` is built from these tokens rather than a literal
/// number, this one-file bump is what carries the softer feel through the
/// whole app.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Motion durations/curves. All animations must respect the platform's
/// "Reduce Motion" accessibility setting — see [AppMotion.durationFor].
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// A soft overshoot curve for small, high-frequency "micro-delight"
  /// interactions (favorite toggle, button press feedback) — 2026's
  /// physics-based-spring motion trend, without pulling in a physics
  /// simulation package for what's fundamentally still a fixed-duration
  /// `AnimatedX` widget. Reserve this for *tap feedback*, not page/route
  /// transitions, where a plain [medium]/`Curves.easeOutCubic` reads
  /// calmer and more predictable.
  static const Curve spring = Curves.easeOutBack;

  /// Returns [Duration.zero] when the platform requests reduced motion,
  /// otherwise [normal]. Call with `MediaQuery.disableAnimationsOf(context)`.
  static Duration durationFor(bool reduceMotion, [Duration normal = medium]) {
    return reduceMotion ? Duration.zero : normal;
  }
}
