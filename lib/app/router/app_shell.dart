import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import 'route_paths.dart';

/// The persistent frame around the app's four primary destinations
/// (Нүүр/Хайх/Захиалга/Хэтэвч) plus a shared, centered "Хөрөнгө нэмэх"
/// action.
///
/// 2026 reference redesign dropped the fifth Профайл tab in favor of the
/// header avatar `HomeScreen`'s `_ProfileAvatar` already provides — a
/// second, less-visible way to reach the same screen was redundant once
/// the avatar shortcut existed. The round add-asset button moved here
/// (was `FloatingActionButton.extended` on `HomeScreen`'s own `Scaffold`)
/// so every tab gets it, centered over the bottom bar, matching the
/// reference design instead of a corner-floating pill on Home alone.
///
/// Adaptive per Material 3's window size classes (see [AppBreakpoints]) —
/// a bottom [NavigationBar] on a normal phone-width screen (the only case
/// this shipped with before), but a side [NavigationRail] once there's
/// room for one: a large phone turned landscape, a split-screen or
/// unfolded-foldable window, a tablet. Both inherit platform safe-area
/// handling for free — neither ever collides with a gesture nav bar on
/// Android or the home indicator on iOS. `_AddAssetFab` (below) is shared
/// by both branches so add-asset access never depends on window width —
/// only its *position* changes: docked into the bottom bar's notch when
/// compact, Flutter's default corner spot when there's a rail instead.
///
/// [navigationShell] is supplied by go_router's `StatefulShellRoute` — see
/// `app_router.dart`. Each branch keeps its own [Navigator], so switching
/// tabs preserves scroll position and any pushed sub-screens in the tab
/// you're leaving — true regardless of which nav widget is on screen.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Re-tapping the already-active tab pops that tab's stack back to its
    // root instead of doing nothing — the behavior users expect from
    // every major tabbed app (Instagram, App Store, etc.).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final List<_Destination> destinations = [
      _Destination(Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      _Destination(Icons.search_outlined, Icons.search_rounded, l10n.navSearch),
      _Destination(Icons.event_note_outlined, Icons.event_note_rounded, l10n.navBookings),
      _Destination(
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        l10n.navWallet,
      ),
    ];

    // `LayoutBuilder`, not `MediaQuery.sizeOf(context)` — this widget's own
    // constraints are what matter (e.g. if it's ever hosted inside a
    // narrower pane on a very large screen), not the full device width.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isCompact(constraints.maxWidth)) {
          return Scaffold(
            body: navigationShell,
            // `BottomAppBar` + `CircularNotchedRectangle`, not
            // `NavigationBar` — a plain `NavigationBar` has no way to carve
            // a notch, so a `centerDocked` FAB next to one only floats
            // *over* the bar's top edge, never looks like part of it. The
            // notch is what makes the round button read as embedded in the
            // bar rather than a separate circle overlapping it, matching
            // the reference design. The tradeoff: `NavigationDestination`'s
            // Material 3 pill-indicator styling doesn't exist for a
            // `BottomAppBar`'s children, so `_BottomNavItem` below hand-rolls
            // the same icon+label/selected-state look instead.
            bottomNavigationBar: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              padding: EdgeInsets.zero,
              color: colors.surface,
              // Flutter's `BottomAppBar` default elevation (8) reads as a
              // fairly heavy card shadow — the design spec wants the nav
              // bar's lift "маш зөөлөн" (very soft), so it's turned down
              // close to flat; the hairline it sits above still separates
              // it from content without a strong drop shadow.
              elevation: 1,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 0; i < 2; i++)
                            _BottomNavItem(
                              destination: destinations[i],
                              isSelected: navigationShell.currentIndex == i,
                              onTap: () => _onDestinationSelected(i),
                            ),
                        ],
                      ),
                    ),
                    // Reserves the room `CircularNotchedRectangle` carves
                    // its cutout into — without this gap the two side
                    // groups would sit directly under the FAB instead of
                    // leaving it its own notch.
                    const SizedBox(width: 56),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 2; i < destinations.length; i++)
                            _BottomNavItem(
                              destination: destinations[i],
                              isSelected: navigationShell.currentIndex == i,
                              onTap: () => _onDestinationSelected(i),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButton: _AddAssetFab(colors: colors, l10n: l10n),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          );
        }

        // Medium/expanded: a side rail frees up the full screen width for
        // content instead of a bottom bar eating into a wide landscape
        // view, and puts navigation within thumb's reach on a large
        // unfolded foldable held like a book. `extended` only once there's
        // genuinely expanded room (tablet/desktop-class width) — at medium
        // width an extended rail's text labels would crowd the content pane.
        final bool extended = AppBreakpoints.isExpanded(constraints.maxWidth);
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  extended: extended,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
          // No bottom bar to dock against here, so this stays at Flutter's
          // default corner position rather than `centerDocked` — same
          // widget as the compact branch above (via `_AddAssetFab`) so a
          // tablet/desktop-width session doesn't lose the ability to add a
          // listing that the compact branch's docked one provides.
          floatingActionButton: _AddAssetFab(colors: colors, l10n: l10n),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The shared "Хөрөнгө нэмэх" round FAB — one definition used by both the
/// compact (docked into the `BottomAppBar`'s notch) and medium/expanded
/// (default corner position, no bottom bar to dock against) branches, so
/// the two can never drift out of sync with each other the way a copy in
/// each branch could.
class _AddAssetFab extends StatelessWidget {
  const _AddAssetFab({required this.colors, required this.l10n});

  final AppColors colors;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Round, not `.extended` — the reference design's center button is a
    // plain "+" circle, not a pill with a text label (unlike `EmptyState`'s
    // "Хөрөнгө нэмэх" action, which keeps its label since it isn't sitting
    // inside a bottom bar's tight vertical space).
    return FloatingActionButton(
      onPressed: () => context.pushNamed(RouteNames.assetCreate),
      // Soft, not the Material default drop shadow — matches the rest of
      // the design spec's "маш зөөлөн" (very soft) shadow direction.
      elevation: 2,
      highlightElevation: 4,
      backgroundColor: colors.accent,
      // Matches `app_theme.dart`'s `onPrimary` fix — white-on-yellow was
      // the exact illegible-contrast bug that fix exists for, and a raw
      // `FloatingActionButton` doesn't route through `ColorScheme.onPrimary`
      // on its own, so it needs the same fixed dark foreground spelled out
      // explicitly here.
      foregroundColor: const Color(0xFF171717),
      tooltip: l10n.addAssetAction,
      child: const Icon(Icons.add_rounded),
    );
  }
}

/// Hand-rolled icon+label nav item for the compact `BottomAppBar` — see
/// that `Scaffold`'s `bottomNavigationBar` comment for why `NavigationBar`
/// (whose `NavigationDestination` would normally do this) can't be used
/// alongside a notch.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final _Destination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color color = isSelected ? colors.accent : colors.secondary;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? destination.selectedIcon : destination.icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
