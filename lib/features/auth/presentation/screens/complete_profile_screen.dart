import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/identity_details_controller.dart';

/// Collects овог/нэр + регистрийн дугаар right after phone/OTP sign-up —
/// the second step of the confirmed registration flow (phone/OTP first,
/// since that's this app's actual Supabase Auth credential; this step
/// second; DAN verification third and still skippable — see
/// `VerificationScreen`'s `isPostRegistration`).
///
/// Reached two ways: `app_router.dart`'s redirect sends any signed-in
/// user here who doesn't have an `identity_details` row yet (covers both
/// a brand-new sign-up and someone who closed the app mid-flow earlier),
/// and there is deliberately no way to skip it — unlike DAN verification,
/// which stays optional, a renter/owner's real name and register number
/// are treated as baseline account information the product needs from
/// everyone, not a later nice-to-have.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _givenNameController = TextEditingController();
  final TextEditingController _registerNumberController = TextEditingController();

  String? _surnameError;
  String? _givenNameError;
  String? _registerNumberError;

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNameController.dispose();
    _registerNumberController.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final String surname = _surnameController.text.trim();
    final String givenName = _givenNameController.text.trim();
    final String registerNumber = Validators.normalizeRegisterNumber(_registerNumberController.text);

    setState(() {
      _surnameError = Validators.requiredField(surname) != null ? l10n.authSurnameRequired : null;
      _givenNameError = Validators.requiredField(givenName) != null ? l10n.authGivenNameRequired : null;
      _registerNumberError =
          Validators.isValidRegisterNumber(registerNumber) ? null : l10n.authRegisterNumberInvalid;
    });
    if (_surnameError != null || _givenNameError != null || _registerNumberError != null) {
      return;
    }

    ref.read(identityDetailsControllerProvider.notifier).submit(
          surname: surname,
          givenName: givenName,
          registerNumber: registerNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final IdentityDetailsSubmitState state = ref.watch(identityDetailsControllerProvider);
    final bool isSubmitting = state is IdentityDetailsSubmitting;

    ref.listen<IdentityDetailsSubmitState>(identityDetailsControllerProvider, (previous, next) {
      if (next is IdentityDetailsSubmitted) {
        // Straight into DAN verification, `isPostRegistration: true` so
        // that screen's own success/skip actions land on Нүүр instead of
        // trying to `pop()` back to a step that's now done. `go` (not
        // `push`) — there's nothing to come back to here either.
        context.go(RoutePaths.verification, extra: true);
      } else if (next is IdentityDetailsSubmitFailed) {
        final String message;
        if (next.failure is ConflictFailure && next.failure.message == 'register_number_already_used') {
          message = l10n.authRegisterNumberAlreadyUsed;
        } else {
          final (_, msg) = failurePresentation(next.failure, l10n);
          message = msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.authCompleteProfileTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.authCompleteProfileBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xxxl),
              AppTextField(
                controller: _surnameController,
                label: l10n.authSurnameLabel,
                errorText: _surnameError,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _givenNameController,
                label: l10n.authGivenNameLabel,
                errorText: _givenNameError,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _registerNumberController,
                label: l10n.authRegisterNumberLabel,
                hintText: l10n.authRegisterNumberHint,
                errorText: _registerNumberError,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: l10n.authCompleteProfileSubmitAction,
                isLoading: isSubmitting,
                onPressed: () => _submit(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
