import 'package:flutter/widgets.dart';

/// Material 3 "window size class" breakpoints (compact / medium /
/// expanded), so the app adapts to every phone/tablet/foldable screen it
/// runs on instead of assuming one fixed phone width — the same adaptive
/// layout convention Google's own 2026 Material apps ship (nav rail
/// instead of a bottom bar once there's room, multi-pane instead of
/// full-screen pushes on wide screens, etc.).
///
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
/// (compact <600dp — nearly every phone in portrait; medium 600–840dp —
/// large phones in landscape, small/split-screen tablets, unfolded
/// foldables; expanded ≥840dp — tablets, desktop windows).
class AppBreakpoints {
  const AppBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;

  static bool isCompact(double width) => width < medium;
  static bool isMedium(double width) => width >= medium && width < expanded;
  static bool isExpanded(double width) => width >= expanded;

  /// Convenience read straight from [BuildContext] — `AppBreakpoints.isCompact`
  /// etc. take a raw width for widgets that already have one on hand (e.g.
  /// inside a `LayoutBuilder`), this is for everywhere else.
  static bool isCompactOf(BuildContext context) => isCompact(MediaQuery.sizeOf(context).width);
  static bool isMediumOf(BuildContext context) => isMedium(MediaQuery.sizeOf(context).width);
  static bool isExpandedOf(BuildContext context) => isExpanded(MediaQuery.sizeOf(context).width);
}
