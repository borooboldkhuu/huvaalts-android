import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_dots.dart';

/// Minimal 3-step onboarding (spec section 8).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (!mounted) return;
    context.go(RoutePaths.authPhone);
  }

  static const int _slideCount = 3;

  void _next() {
    final int current = ref.read(onboardingControllerProvider);
    if (current == _slideCount - 1) {
      unawaited(_finish());
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = ref.watch(onboardingControllerProvider);
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> titles = [l10n.onboardingTitle1, l10n.onboardingTitle2, l10n.onboardingTitle3];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            const _BrandBanner(),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slideCount,
                onPageChanged: (index) =>
                    ref.read(onboardingControllerProvider.notifier).setPage(index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration placeholder — replace with production
                        // art per slide once final assets are supplied.
                        Container(
                          height: 220,
                          width: 220,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 72,
                            color: theme.colorScheme.primary.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        Text(
                          titles[index],
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            OnboardingDots(count: _slideCount, currentIndex: currentIndex),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: PrimaryButton(
                label: currentIndex == _slideCount - 1 ? l10n.onboardingCta : l10n.commonContinue,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "ХУВААЛЦ / share • connect • grow" wordmark banner shown once,
/// pinned above the swipeable slides — a persistent brand header rather
/// than something repeated on all three slides. Pure typography, no image
/// asset: the wide `letterSpacing` on [AppTypography]'s Manrope
/// `displayLarge` is what gives the wordmark its spaced-out banner feel,
/// paired with a small tracked all-caps tagline in the muted secondary
/// color underneath — a first pass built from a text description. If a
/// reference design image comes in, swap this widget's contents to match
/// it exactly (colors/spacing/any mark) without touching how it's wired
/// into the screen above.
class _BrandBanner extends StatelessWidget {
  const _BrandBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Text(
          l10n.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 30, letterSpacing: 6),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.brandTagline.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 3,
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
