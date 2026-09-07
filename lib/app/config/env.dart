enum AppEnvironment { development, staging, production }

/// Central accessor for build-time environment configuration.
///
/// SUPERSEDES a `flutter_dotenv`-based design that read a `.env.<flavor>`
/// file bundled as a Flutter *asset*. That had a real information-
/// disclosure bug (found in an external audit, Aug 2026): `pubspec.yaml`
/// listed **all three** `.env.development` / `.env.staging` /
/// `.env.production` files as assets unconditionally, so every build —
/// including a release production APK/IPA — shipped with the
/// development and staging config readable inside it (Flutter assets
/// are stored as plain files in the package, trivially extracted by
/// unzipping the APK/IPA). There is no way to make Flutter's `assets:`
/// list vary per build flavor without extra tooling, so "stop bundling
/// the other two files" wasn't fixable by editing that list alone.
///
/// The actual fix: values now come from `--dart-define-from-file`,
/// resolved to compile-time constants via [String.fromEnvironment].
/// Nothing is bundled as a readable asset at all — a production build
/// invoked with `--dart-define-from-file=env/production.json` embeds
/// *only* whatever's in that one file, baked in as literal constants at
/// compile time; `env/development.json`/`env/staging.json` are never
/// read, referenced, or present in that build's output in any form.
/// See `env/development.json` / `env/staging.json` / `env/production.json`
/// (the JSON replacements for the old `.env.*` files) and README's
/// "Getting started" / "Environment configuration" sections for the
/// exact commands.
///
/// IMPORTANT: only client-safe values belong here (Supabase URL + anon
/// key, public Maps key, feature flags). Service-role keys, DAN client
/// secrets, and payment provider secret keys must never be read into
/// the Flutter binary — they live in Supabase Edge Function secrets /
/// backend config only (spec sections 9, 19, 32, 34).
class Env {
  const Env._();

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _backendApiBaseUrl = String.fromEnvironment('BACKEND_API_BASE_URL');

  static String get supabaseUrl => _require('SUPABASE_URL', _supabaseUrl);
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY', _supabaseAnonKey);
  static String get googleMapsApiKey => _require('GOOGLE_MAPS_API_KEY', _googleMapsApiKey);
  static String get backendApiBaseUrl => _require('BACKEND_API_BASE_URL', _backendApiBaseUrl);

  /// `mock` until real DAN integration credentials/docs are available;
  /// switching to `production` must not require rewriting call sites —
  /// see `DanAuthServiceFactory`.
  static const String danAuthMode = String.fromEnvironment('DAN_AUTH_MODE', defaultValue: 'mock');

  static const String paymentProvider = String.fromEnvironment('PAYMENT_PROVIDER', defaultValue: 'mock');

  static double get defaultCommissionPercent {
    const String raw = String.fromEnvironment('PLATFORM_COMMISSION_DEFAULT_PERCENT', defaultValue: '10');
    return double.tryParse(raw) ?? 10;
  }

  /// True when [value] still looks like one of this repo's own
  /// placeholder strings (`placeholder-...`) rather than a real
  /// configured value — used by [AppConfig] to refuse booting a
  /// `production`-flavor build that was never actually configured (see
  /// that class for why this matters: a placeholder `.env`/dart-define
  /// file is meant to be a scaffold, never something that reaches an
  /// actual release build).
  static bool looksLikePlaceholder(String value) => value.contains('placeholder');

  static String _require(String key, String value) {
    if (value.isEmpty) {
      throw StateError(
        'Missing required --dart-define-from-file value "$key". Did you '
        'pass --dart-define-from-file=env/<flavor>.json when running/'
        'building (e.g. --dart-define-from-file=env/development.json)?',
      );
    }
    return value;
  }
}
