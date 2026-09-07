import 'env.dart';

/// Riverpod-injectable snapshot of the resolved environment, so widgets and
/// controllers don't call into [Env]'s static/global state directly and can
/// be tested with a fake config.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleMapsApiKey,
    required this.backendApiBaseUrl,
    required this.danAuthMode,
    required this.paymentProvider,
    required this.defaultCommissionPercent,
  });

  factory AppConfig.fromEnv(AppEnvironment environment) {
    return AppConfig(
      environment: environment,
      supabaseUrl: Env.supabaseUrl,
      supabaseAnonKey: Env.supabaseAnonKey,
      googleMapsApiKey: Env.googleMapsApiKey,
      backendApiBaseUrl: Env.backendApiBaseUrl,
      danAuthMode: Env.danAuthMode,
      paymentProvider: Env.paymentProvider,
      defaultCommissionPercent: Env.defaultCommissionPercent,
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleMapsApiKey;
  final String backendApiBaseUrl;
  final String danAuthMode;
  final String paymentProvider;
  final double defaultCommissionPercent;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDanMock => danAuthMode != 'production';

  /// True if any client-safe config value still looks like this repo's
  /// own placeholder scaffolding (`placeholder-...`) rather than a real
  /// configured value. Added after an external audit (Aug 2026) flagged
  /// that nothing stopped `env/production.json`'s placeholder values
  /// from silently shipping in an actual release build — see
  /// [assertNotPlaceholderInProduction].
  bool get hasPlaceholderValues =>
      Env.looksLikePlaceholder(supabaseUrl) ||
      Env.looksLikePlaceholder(supabaseAnonKey) ||
      Env.looksLikePlaceholder(googleMapsApiKey) ||
      Env.looksLikePlaceholder(backendApiBaseUrl);

  /// Refuses to let a `production`-flavor build boot at all if it was
  /// never actually configured — called from `bootstrap()` before
  /// `runApp`. Deliberately a hard crash, not a graceful in-app error
  /// screen: a placeholder reaching this check at all means release
  /// tooling shipped a scaffold file, which should be caught in CI/QA
  /// long before it could reach an end user's device — the loud failure
  /// is for whoever's building the release, not for a real user.
  /// `development`/`staging` builds are exempt: their own placeholder
  /// values (`env/staging.json`) are an expected, documented scaffold
  /// state until those environments are actually stood up.
  void assertNotPlaceholderInProduction() {
    if (isProduction && hasPlaceholderValues) {
      throw StateError(
        'Refusing to boot: this is a `production`-flavor build but its '
        'configuration still has placeholder value(s) from '
        'env/production.json (supabaseUrl/supabaseAnonKey/'
        'googleMapsApiKey/backendApiBaseUrl). Fill in real production '
        'values in env/production.json (or your CI/release pipeline\'s '
        'equivalent --dart-define-from-file) before shipping this build.',
      );
    }
  }
}
