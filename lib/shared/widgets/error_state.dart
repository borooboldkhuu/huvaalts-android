import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/errors/failure.dart';
import 'primary_button.dart';

/// Renders a [Failure] as a friendly, localized message + retry action.
/// Never surfaces `failure.message` raw to end users (spec section 39) —
/// this maps each [Failure] subtype to a localized string instead.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (IconData icon, String message) = failurePresentation(failure, l10n);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: 200,
            child: PrimaryButton(label: l10n.commonRetry, onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

/// Maps a [Failure] to a localized (icon, message) pair — the single
/// source [ErrorStateView] renders full-screen and anything showing a
/// one-off failure (e.g. a `SnackBar` after a failed form submit) can reuse
/// instead of re-deriving its own copy of this switch.
(IconData, String) failurePresentation(Failure failure, AppLocalizations l10n) {
  return switch (failure) {
    NetworkFailure() => (Icons.wifi_off_rounded, l10n.errorNetwork),
    // `SessionExpiredException`'s default message ('session_expired')
    // is the only thing that still distinguishes it from a plain
    // `UnauthorizedException` once both collapse into `AuthFailure` in
    // `Failure.from` — without checking it, `errorSessionExpired` could
    // never actually be shown.
    AuthFailure() => (
        Icons.lock_outline,
        failure.message == 'session_expired' ? l10n.errorSessionExpired : l10n.errorAuthRequired,
      ),
    PermissionFailure() => (Icons.block, l10n.errorPermission),
    NotFoundFailure() => (Icons.search_off, l10n.errorNotFound),
    ValidationFailure() => (Icons.error_outline, l10n.errorValidation),
    ConflictFailure() => (Icons.error_outline, l10n.errorConflict),
    RateLimitFailure() => (Icons.hourglass_bottom, l10n.errorRateLimited),
    UnexpectedFailure() => (Icons.error_outline, l10n.errorUnknown),
  };
}
