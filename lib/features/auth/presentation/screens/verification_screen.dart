import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/verification_controller.dart';

/// The DAN "Get verified" flow (spec section 9). Reachable from Profile
/// once `verificationLevel < verificationLevelDan`.
///
/// KNOWN LIMITATION: a real DAN consent flow needs the government
/// service to redirect back into this app after consent (a deep
/// link/universal link callback) before polling would ever see anything
/// but `pending`. That callback plumbing isn't wired up — same class of
/// gap as Google/Apple native sign-in (see README "Known issues"). This
/// screen's "I've given consent" button is a manual stand-in for that
/// callback: after opening the real consent page in a browser, the user
/// taps it themselves to trigger a status check, rather than the app
/// resuming automatically. Wiring the real callback is a follow-up once
/// DAN's actual redirect contract is known.
///
/// Whenever the session's consent URL is this project's own mock
/// placeholder host (`mock-dan.local` — returned by both
/// `MockDanAuthAdapter` and `dan-verify`'s mock branch), an in-app mock
/// consent step is shown instead of trying to open a browser to a
/// domain that doesn't exist. That single host check is enough to make
/// this screen behave correctly whether the backend is mocked or real,
/// with no other branching needed.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({this.isPostRegistration = false, super.key});

  /// True when this screen was reached right after `CompleteProfileScreen`
  /// (registration's confirmed flow: phone/OTP -> name/regnum -> DAN),
  /// rather than later from Profile's "Get verified" action. Changes two
  /// things: an extra "Verify later" action on the intro step (DAN stays
  /// optional either way — a government-service outage must never trap a
  /// new user out of the app), and where success/failure "done" actions
  /// go — `context.go(RoutePaths.home)` instead of `Navigator.maybePop()`,
  /// since there's nothing on the nav stack to pop back to here (the
  /// router replaced, not pushed, on the way in).
  final bool isPostRegistration;

  static const String _mockConsentHost = 'mock-dan.local';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final VerificationState state = ref.watch(verificationControllerProvider);
    final String? userId = ref.watch(authControllerProvider).value?.id;

    ref.listen<VerificationState>(verificationControllerProvider, (previous, next) {
      if (next.step == VerificationStep.verified && userId != null) {
        ref.invalidate(profileProvider(userId));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verificationScreenTitle),
        automaticallyImplyLeading: !isPostRegistration,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _buildStep(context, ref, l10n, theme, state),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    VerificationState state,
  ) {
    switch (state.step) {
      case VerificationStep.idle:
        return _IntroView(
          l10n: l10n,
          theme: theme,
          onStart: () => ref.read(verificationControllerProvider.notifier).start(),
          onSkip: isPostRegistration ? () => context.go(RoutePaths.home) : null,
        );
      case VerificationStep.startingSession:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.verificationStartingLabel, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      case VerificationStep.awaitingConsent:
        final session = state.session!;
        final bool isMock = Uri.tryParse(session.consentUrl)?.host == _mockConsentHost;
        return _ConsentView(
          l10n: l10n,
          theme: theme,
          isMock: isMock,
          consentUrl: session.consentUrl,
          onConfirm: () => ref.read(verificationControllerProvider.notifier).confirmConsentAndPoll(),
        );
      case VerificationStep.polling:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.verificationPollingLabel, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      case VerificationStep.verified:
        return _SuccessView(
          l10n: l10n,
          theme: theme,
          onDone: () => isPostRegistration
              ? context.go(RoutePaths.home)
              : Navigator.of(context).maybePop(),
        );
      case VerificationStep.failed:
        return _FailedView(
          l10n: l10n,
          theme: theme,
          error: state.error,
          onRetry: () => ref.read(verificationControllerProvider.notifier).reset(),
        );
    }
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.l10n, required this.theme, required this.onStart, this.onSkip});

  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onStart;

  /// Non-null only when reached post-registration — see
  /// `VerificationScreen.isPostRegistration`'s doc comment.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.verificationIntroTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.verificationIntroBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(label: l10n.verificationStartAction, onPressed: onStart),
        if (onSkip != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(onPressed: onSkip, child: Text(l10n.verificationSkipForNowAction)),
          ),
        ],
      ],
    );
  }
}

class _ConsentView extends StatelessWidget {
  const _ConsentView({
    required this.l10n,
    required this.theme,
    required this.isMock,
    required this.consentUrl,
    required this.onConfirm,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isMock;
  final String consentUrl;
  final VoidCallback onConfirm;

  Future<void> _openRealConsentUrl() async {
    final Uri uri = Uri.parse(consentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.verificationConsentTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.verificationConsentBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        if (isMock)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.verificationMockConsentWarning,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          )
        else
          SecondaryButton(label: l10n.verificationOpenConsentAction, onPressed: _openRealConsentUrl),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: isMock ? l10n.verificationMockConsentAction : l10n.verificationIveCompletedAction,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.l10n, required this.theme, required this.onDone});

  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 56, color: context.colors.success),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.verificationSuccessTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.verificationSuccessBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(label: l10n.verificationDoneAction, onPressed: onDone),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    required this.l10n,
    required this.theme,
    required this.error,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final Object? error;
  final VoidCallback onRetry;

  String _messageFor(Object? error) {
    if (error is VerificationTimeoutException) return l10n.verificationTimeoutMessage;
    if (error == null) return l10n.errorUnknown;
    final (_, message) = failurePresentation(Failure.from(error), l10n);
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.verificationFailedTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(_messageFor(error), style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xxl),
        PrimaryButton(label: l10n.verificationTryAgainAction, onPressed: onRetry),
      ],
    );
  }
}
