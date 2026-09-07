import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/otp_controller.dart';
import '../widgets/social_auth_buttons.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(otpControllerProvider.notifier).submitPhone(_phoneController.text);
    final OtpStep step = ref.read(otpControllerProvider);
    if (step is OtpStepEnterCode && mounted) {
      context.pushNamed(RouteNames.authOtp, extra: step.phoneE164);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OtpStep step = ref.watch(otpControllerProvider);
    final bool isSubmitting = step is OtpStepEnterPhone && step.isSubmitting;
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    // `OtpController.submitPhone` stores two very different kinds of
    // failure under the same `step.failure` field: a client-side format
    // rejection (`ValidationFailure('auth_invalid_phone', ...)`, thrown
    // before any network call) versus whatever `sendPhoneOtp()` itself
    // threw (network error, Supabase project/phone-provider misconfig,
    // rate limit, ...). This used to always show `authInvalidPhone`
    // regardless of which one it was — so a real backend/network error
    // rendered as "утасны дугаар буруу байна" even when the number was
    // perfectly valid, which is actively misleading during setup/testing.
    // Only the specific client-side code gets the phone-format message;
    // anything else goes through the same `failurePresentation` mapping
    // every other screen uses, so the actual problem is visible.
    final Failure? phoneFailure = step is OtpStepEnterPhone ? step.failure : null;
    final String? errorText = switch (phoneFailure) {
      null => null,
      ValidationFailure(message: 'auth_invalid_phone') => l10n.authInvalidPhone,
      final Failure other => failurePresentation(other, l10n).$2,
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text(l10n.authPhoneTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xxxl),
              AppTextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixText: '+976 ',
                hintText: l10n.authPhoneHint,
                errorText: errorText,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l10n.commonContinue,
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(l10n.authOr, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SocialAuthButtons(
                onGooglePressed: () {
                  // Wired once google_sign_in native setup (Android
                  // SHA-1/iOS URL scheme) is added to the platform projects.
                },
                onApplePressed: () {
                  // Wired once Sign In with Apple capability is added to
                  // the iOS project.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
