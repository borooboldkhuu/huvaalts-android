import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';

sealed class OtpStep {
  const OtpStep();
}

class OtpStepEnterPhone extends OtpStep {
  const OtpStepEnterPhone({this.isSubmitting = false, this.failure});
  final bool isSubmitting;
  final Failure? failure;
}

class OtpStepEnterCode extends OtpStep {
  const OtpStepEnterCode({
    required this.phoneE164,
    this.isSubmitting = false,
    this.failure,
    this.resendCooldownSeconds = 0,
  });
  final String phoneE164;
  final bool isSubmitting;
  final Failure? failure;
  final int resendCooldownSeconds;
}

class OtpStepVerified extends OtpStep {
  const OtpStepVerified(this.user);
  final AppUser user;
}

/// Drives the phone -> OTP -> verified flow. Kept separate from the broader
/// [AuthController] so the multi-step UI state (which step, cooldown timer,
/// per-field errors) doesn't leak into the app-wide "who is signed in"
/// state.
class OtpController extends Notifier<OtpStep> {
  @override
  OtpStep build() => const OtpStepEnterPhone();

  Future<void> submitPhone(String rawPhone) async {
    if (!Validators.isValidMongolianPhone(rawPhone)) {
      state = OtpStepEnterPhone(
        failure: const ValidationFailure('auth_invalid_phone', null),
      );
      return;
    }
    final String phoneE164 = Validators.normalizePhone(rawPhone);
    state = const OtpStepEnterPhone(isSubmitting: true);
    try {
      await ref.read(authRepositoryProvider).sendPhoneOtp(phoneE164);
      state = OtpStepEnterCode(phoneE164: phoneE164, resendCooldownSeconds: 60);
    } catch (e) {
      state = OtpStepEnterPhone(failure: Failure.from(e));
    }
  }

  Future<void> submitOtp(String code) async {
    final OtpStep current = state;
    if (current is! OtpStepEnterCode) return;
    if (!Validators.isValidOtp(code)) {
      state = OtpStepEnterCode(
        phoneE164: current.phoneE164,
        resendCooldownSeconds: current.resendCooldownSeconds,
        failure: const ValidationFailure('auth_invalid_otp', null),
      );
      return;
    }
    state = OtpStepEnterCode(
      phoneE164: current.phoneE164,
      isSubmitting: true,
      resendCooldownSeconds: current.resendCooldownSeconds,
    );
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .verifyPhoneOtp(phoneE164: current.phoneE164, otp: code);
      state = OtpStepVerified(user);
    } catch (e) {
      state = OtpStepEnterCode(
        phoneE164: current.phoneE164,
        resendCooldownSeconds: current.resendCooldownSeconds,
        failure: Failure.from(e),
      );
    }
  }

  void reset() => state = const OtpStepEnterPhone();
}

final NotifierProvider<OtpController, OtpStep> otpControllerProvider =
    NotifierProvider<OtpController, OtpStep>(OtpController.new);
