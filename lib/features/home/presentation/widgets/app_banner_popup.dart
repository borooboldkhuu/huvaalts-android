import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/entities/app_banner.dart';

/// Shows the rotating app-open banner popup (`public.app_banners`,
/// admin-managed via `AdminBannersScreen`). Called once from
/// `HomeScreen`'s first post-frame callback, only when [banners] is
/// non-empty — see that screen's `_maybeShowAppBannerPopup`.
///
/// Deliberately has no tap-through action on the image itself (confirmed
/// with the user: closing the popup, or swiping/auto-advancing to the
/// next banner, is the only interaction) — unlike `FeaturedAssetCarousel`
/// this never navigates anywhere.
Future<void> showAppBannerPopup(BuildContext context, List<AppBanner> banners) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _AppBannerPopupDialog(banners: banners),
  );
}

class _AppBannerPopupDialog extends StatefulWidget {
  const _AppBannerPopupDialog({required this.banners});

  final List<AppBanner> banners;

  @override
  State<_AppBannerPopupDialog> createState() => _AppBannerPopupDialogState();
}

class _AppBannerPopupDialogState extends State<_AppBannerPopupDialog> {
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // "Olon banner, ergeldeg" (multiple, rotating) — auto-advances every
    // 4s in addition to manual swipe; stops trying once every banner has
    // been shown once rather than looping forever, since this is a
    // one-shot app-open popup, not an ambient carousel.
    if (widget.banners.length > 1) {
      _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_pageController.hasClients) return;
        final int next = _currentPage + 1;
        if (next >= widget.banners.length) {
          _autoAdvanceTimer?.cancel();
          return;
        }
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxxl),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 2,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.banners.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final AppBanner banner = widget.banners[index];
                  return CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.banners.length > 1)
            Positioned(
              bottom: AppSpacing.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (index) {
                  final bool isCurrent = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isCurrent ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  );
                }),
              ),
            ),
          Positioned(
            top: -14,
            right: -14,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
