import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/entities/app_banner.dart';
import '../../../../shared/widgets/category_chip_row.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../assets/domain/entities/asset_search_filters.dart';
import '../../../assets/presentation/controllers/asset_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notification_providers.dart';
import '../controllers/app_banner_providers.dart';
import '../controllers/nearby_location_provider.dart';
import '../widgets/app_banner_popup.dart';
import '../widgets/asset_home_section.dart';
import '../widgets/featured_asset_carousel.dart';
import '../widgets/quick_filter_pills.dart';

/// Whether the app-open banner popup has already been shown this app
/// session — module-level (not a provider/persisted flag) is deliberate:
/// its whole lifetime should match the running process, resetting
/// naturally on the next real app open, which is exactly what "show once
/// per app open" (the user's ask) means. `HomeScreen` can remount many
/// times in one session (tab navigation, pull-to-refresh) without this
/// re-triggering the popup each time.
bool _appBannerPopupShownThisSession = false;

/// Home (spec section 11) — the "Юу хэрэгтэй байна?" surface: search entry
/// point, category chips, a prominent "+ Хөрөнгө нэмэх" action, and the
/// discovery sections. Asset creation itself and full asset detail are
/// Phase 3 — this screen wires up real browsing against `public.assets`
/// today and leaves clearly-labeled placeholders for those two.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (!_appBannerPopupShownThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAppBannerPopup());
    }
  }

  Future<void> _maybeShowAppBannerPopup() async {
    if (_appBannerPopupShownThisSession || !mounted) return;
    // `.future` (not `.value`) deliberately — the popup should still show
    // if the query hasn't resolved by the first frame, not silently skip
    // itself just because it was asked before the data arrived.
    final List<AppBanner> banners;
    try {
      banners = await ref.read(activeAppBannersProvider.future);
    } catch (_) {
      // Best-effort, same as `nearbyLocationProvider` — a failed banner
      // fetch should never block or crash Home.
      return;
    }
    if (banners.isEmpty || !mounted) return;
    _appBannerPopupShownThisSession = true;
    await showAppBannerPopup(context, banners);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final nearby = ref.watch(nearbyLocationProvider).value;
    final appUser = ref.watch(authControllerProvider).value;
    final String? userId = appUser?.id;
    final ThemeData theme = Theme.of(context);
    final AppColors colors = context.colors;

    // "Popular" (mostViewed, no location/price/verified constraints) is
    // the least-restrictive query of the seven — an empty result there is
    // a reliable proxy for "the whole catalog is empty right now" without
    // watching all seven providers just to answer that one question.
    // Riverpod dedupes this against the identical watch Popular's own
    // `AssetHomeSection` makes below, so it's not a second network call.
    const AssetSearchFilters popularFilters = AssetSearchFilters(sort: AssetSortOption.mostViewed);
    final popularAsync = ref.watch(homeSectionProvider(popularFilters));
    final bool catalogEmpty = popularAsync.hasValue && popularAsync.value!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        // Taller than the default 56 — the title is now two lines
        // (wordmark + location), matching the 2026 reference redesign.
        // Plain `title: Column(...)` rather than `flexibleSpace` +
        // `title` layered together — two positioned widgets sharing one
        // toolbar height risks overlapping/clipping each other depending
        // on exact metrics; a single Column widget as the title lays out
        // top-to-bottom on its own and can't collide with itself.
        toolbarHeight: 72,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appName,
              // Sized up from `titleLarge`'s 20px — the design spec calls
              // for a 26-28px/800 wordmark, a genuine logo treatment
              // rather than a regular screen title.
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            // Was the "📍 Улаанбаатар" location label (`_LocationLabel`,
            // removed below) — dropped at the user's request in favor of
            // the functional "what are you here to do" prompt
            // (`homeWhatDoYouNeed`) that already existed in
            // AppLocalizations but wasn't wired up anywhere yet.
            Text(
              l10n.homeWhatDoYouNeed,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.secondary),
            ),
          ],
        ),
        titleSpacing: AppSpacing.lg,
        actions: [
          if (userId != null) _NotificationBellButton(userId: userId),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg, left: AppSpacing.xs),
            child: _ProfileAvatar(avatarUrl: appUser?.avatarUrl),
          ),
        ],
      ),
      // The old `FloatingActionButton.extended` lived here — moved to
      // `AppShell` so every tab gets the same centered round "+", not just
      // Home (see that file's doc comment for the full reasoning).
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(nearbyLocationProvider);
          // Home section providers auto-invalidate on next read via their
          // filter keys; nothing else to force here for a Phase 2 browse
          // surface with no local write state.
        },
        child: ListView(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.huge),
          children: [
            // The old personalized "Сайн байна уу / Юу хэрэгтэй байна?"
            // greeting block lived here — dropped in the 2026 reference
            // redesign in favor of the header's location line, straight
            // into the search bar. `homeGreeting`/`homeWhatDoYouNeed`
            // stay in AppLocalizations (harmless, still-translated dead
            // code is safer to leave than to chase every reference) in
            // case a later revision wants a personalized touch back.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SearchBarEntry(hint: l10n.searchHint),
            ),
            const SizedBox(height: AppSpacing.lg),
            CategoryChipRow(
              selected: null,
              // `goNamed` (not `pushNamed`): search is now the Хайх bottom
              // tab, so selecting a category should switch to that tab
              // with the filter applied, not push a detached duplicate
              // screen with no nav bar on top of Нүүр — see AppShell.
              onSelected: (category) => context.goNamed(
                RouteNames.search,
                extra: AssetSearchFilters(categoryId: category?.id),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            QuickFilterPills(nearby: nearby),
            const SizedBox(height: AppSpacing.lg),
            // A catalog that's genuinely empty (fresh install, no listings
            // yet) previously fell through silently here: every section
            // hides itself when its own query is empty, so with all seven
            // empty the page just... stopped, leaving a large blank void
            // under the categories row. One page-level empty state instead.
            if (catalogEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                child: EmptyState(
                  icon: Icons.storefront_outlined,
                  title: l10n.emptyAssetsTitle,
                  actionLabel: l10n.addAssetAction,
                  onAction: () => context.pushNamed(RouteNames.assetCreate),
                ),
              )
            else ...[
              // Hero — "Танд санал болгож байна", ONLY `is_featured`
              // assets (see FeaturedAssetCarousel's doc comment for how
              // this differs from the same-titled row further down).
              // Hides itself with no gap when nothing is featured, same
              // as every AssetHomeSection below.
              const FeaturedAssetCarousel(),
              // Each section gets its own icon + accent color (header badge,
              // see AssetHomeSection) so seven stacked sections read as seven
              // distinct ideas, not one repeated block. Trending additionally
              // renders as a 2-column mosaic instead of a horizontal row —
              // meant to be the one section that stops the scroll.
              if (nearby != null)
                AssetHomeSection(
                  title: l10n.sectionNearby,
                  icon: Icons.location_on_rounded,
                  accentColor: colors.accent,
                  filters: AssetSearchFilters(
                    sort: AssetSortOption.closest,
                    nearLatitude: nearby.$1,
                    nearLongitude: nearby.$2,
                    radiusKm: 50,
                  ),
                ),
              AssetHomeSection(
                title: l10n.sectionPopular,
                icon: Icons.visibility_rounded,
                accentColor: theme.colorScheme.tertiary,
                filters: popularFilters,
              ),
              // The "Хуваалцъя, хэмнээ" promo banner and "Миний хэтэвч" wallet
              // card lived here (2026 reference redesign) — removed at the
              // user's request. `PromoValueBanner`/`WalletHomeCard` still
              // exist as standalone widgets (unreferenced now) rather than
              // deleted outright, in case a later revision wants either
              // back; nothing else in the codebase imports them.
              const SizedBox(height: AppSpacing.lg),
              AssetHomeSection(
                title: l10n.sectionRecommended,
                icon: Icons.auto_awesome_rounded,
                accentColor: colors.accent,
                filters: const AssetSearchFilters(sort: AssetSortOption.recommended),
              ),
              AssetHomeSection(
                title: l10n.sectionRecentlyAdded,
                icon: Icons.schedule_rounded,
                accentColor: colors.secondary,
                filters: const AssetSearchFilters(sort: AssetSortOption.newest),
              ),
              AssetHomeSection(
                title: l10n.sectionUnder50k,
                icon: Icons.local_offer_rounded,
                accentColor: colors.success,
                filters: const AssetSearchFilters(maxPrice: 50000, sort: AssetSortOption.newest),
              ),
              AssetHomeSection(
                title: l10n.sectionVerifiedOwners,
                icon: Icons.verified_rounded,
                accentColor: colors.accent,
                filters: const AssetSearchFilters(verifiedOwnersOnly: true, sort: AssetSortOption.newest),
              ),
              AssetHomeSection(
                title: l10n.sectionTrending,
                icon: Icons.local_fire_department_rounded,
                accentColor: colors.warning,
                mosaic: true,
                filters: const AssetSearchFilters(sort: AssetSortOption.mostFavorited),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBarEntry extends StatelessWidget {
  const _SearchBarEntry({required this.hint});

  final String hint;

  // A dedicated radius, not `AppRadius.md` (14) — the 2026 design spec
  // calls out the search bar specifically at 18px, one step past the
  // shared radius scale's "md". Kept local to this widget rather than
  // changed globally, since `AppRadius.md` is shared by many other
  // components the spec didn't ask to change.
  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppColors colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () => context.goNamed(RouteNames.search),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: colors.border),
            // Very soft — a hint of lift, not a heavy card shadow, per the
            // spec's "shadow: маш бага" (very little) direction.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: colors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text(hint, style: theme.textTheme.bodyLarge?.copyWith(color: colors.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell icon + unread-count badge (spec section 24). No push delivery
/// this phase (see `AppNotification`'s header comment) — this badge is
/// the only signal a user gets that something happened while the app was
/// closed, until they reopen it.
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationCountProvider(userId)).value ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => context.pushNamed(RouteNames.notifications),
        ),
        if (unread > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Header avatar (2026 reference redesign) — a shortcut into the Профайл
/// tab. Falls back to the same tinted-circle + person-glyph treatment
/// `ProfileScreen` already uses when there's no photo on file, so a
/// brand-new user sees the identical placeholder in both places.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    const double size = 36;

    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.profile),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => _avatarFallback(colors, size),
                errorWidget: (context, url, error) => _avatarFallback(colors, size),
              )
            : _avatarFallback(colors, size),
      ),
    );
  }

  Widget _avatarFallback(AppColors colors, double size) {
    return Container(
      width: size,
      height: size,
      color: colors.accent.withOpacity(0.12),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: 20, color: colors.accent),
    );
  }
}
