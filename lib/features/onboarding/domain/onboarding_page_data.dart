/// A single onboarding slide's content. Kept as a plain model (not a
/// widget) so the controller/tests can reason about "which slide" without
/// touching Flutter widget classes.
class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.assetPath,
  });

  final String title;

  /// Illustration asset — placeholder path until final art is supplied.
  final String assetPath;
}
