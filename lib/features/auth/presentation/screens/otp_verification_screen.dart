import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/otp_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({required this.phone, super.key});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(otpControllerProvider.notifier).submitOtp(_codeController.text);
    final OtpStep step = ref.read(otpControllerProvider);
    if (step is OtpStepVerified && mounted) {
      // Always aim for home — the router's own redirect (`app_router.dart`)
      // is what actually decides whether a freshly-verified user lands
      // there or gets bounced to `CompleteProfileScreen` first (no
      // `identity_details` row yet), so this screen doesn't need to know
      // or duplicate that check.
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OtpStep step = ref.watch(otpControllerProvider);
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    final bool isSubmitting = step is OtpStepEnterCode && step.isSubmitting;
    final String? errorText =
        step is OtpStepEnterCode && step.failure != null ? l10n.authInvalidOtp : null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.authOtpTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.authOtpSubtitle(widget.phone),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppTextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                hintText: '••••••',
                errorText: errorText,
                maxLength: AppConstants.otpLength,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l10n.commonContinue,
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(otpControllerProvider.notifier).reset();
                    context.pop();
                  },
                  child: Text(l10n.authOtpResend),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
