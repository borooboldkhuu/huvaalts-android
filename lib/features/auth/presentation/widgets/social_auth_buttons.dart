import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Google / Apple sign-in entry points. Wiring to the native SDKs
/// (`google_sign_in`, `sign_in_with_apple`) happens where these callbacks
/// are provided — kept out of this dumb widget so it stays trivially
/// testable.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    required this.onGooglePressed,
    required this.onApplePressed,
    this.showApple = true,
    super.key,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;

  /// Apple Sign-In should only be offered on iOS per App Store guidelines;
  /// callers pass `Platform.isIOS` (or the equivalent adaptive check).
  final bool showApple;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      children: [
        SecondaryButton(
          label: l10n.authContinueWithGoogle,
          icon: Icons.g_mobiledata,
          onPressed: onGooglePressed,
        ),
        if (showApple) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.authContinueWithApple,
            icon: Icons.apple,
            onPressed: onApplePressed,
          ),
        ],
      ],
    );
  }
}
