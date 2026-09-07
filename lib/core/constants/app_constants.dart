/// App-wide constants that are not environment-specific (env-specific
/// values live in `app/config/env.dart`, sourced from
/// `--dart-define-from-file=env/<flavor>.json`).
class AppConstants {
  const AppConstants._();

  static const String appName = 'ХУВААЛЦ';
  static const String tagline = 'Ашигладаггүй зүйлээ мөнгө болго.';

  /// Default platform commission — overridable by Admin (spec section 20).
  /// The client must never compute the *authoritative* commission; this is
  /// only used for optimistic UI preview before the backend confirms.
  static const double defaultCommissionPercent = 10;

  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 60);

  static const String deepLinkScheme = 'huvalts';

  /// Verification levels — see spec section 10.
  static const int verificationLevelPhone = 0;
  static const int verificationLevelDan = 1;
  static const int verificationLevelIdentity = 2;
  static const int verificationLevelBusiness = 3;
}
