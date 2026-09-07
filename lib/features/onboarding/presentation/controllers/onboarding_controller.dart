import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

/// Tracks the current onboarding page index and persists "onboarding
/// complete" so the router never shows onboarding again after the user
/// finishes it once (spec section 8).
class OnboardingController extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int index) => state = index;

  Future<void> complete() async {
    await ref.read(localCacheProvider).setOnboardingComplete(true);
  }
}

final NotifierProvider<OnboardingController, int> onboardingControllerProvider =
    NotifierProvider<OnboardingController, int>(OnboardingController.new);
