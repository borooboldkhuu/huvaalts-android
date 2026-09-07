import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';

sealed class IdentityDetailsSubmitState {
  const IdentityDetailsSubmitState();
}

class IdentityDetailsIdle extends IdentityDetailsSubmitState {
  const IdentityDetailsIdle();
}

class IdentityDetailsSubmitting extends IdentityDetailsSubmitState {
  const IdentityDetailsSubmitting();
}

class IdentityDetailsSubmitted extends IdentityDetailsSubmitState {
  const IdentityDetailsSubmitted();
}

class IdentityDetailsSubmitFailed extends IdentityDetailsSubmitState {
  const IdentityDetailsSubmitFailed(this.failure);
  final Failure failure;
}

/// Drives `CompleteProfileScreen`'s submit — a single-shot save, not a
/// multi-step flow like `OtpController`/`VerificationController`, so its
/// state is just idle/submitting/submitted/failed.
class IdentityDetailsController extends Notifier<IdentityDetailsSubmitState> {
  @override
  IdentityDetailsSubmitState build() => const IdentityDetailsIdle();

  Future<void> submit({
    required String surname,
    required String givenName,
    required String registerNumber,
  }) async {
    // Awaits `.future` rather than reading `.value` synchronously — same
    // reasoning as `VerificationController.start()`: an `AsyncNotifier`
    // can still be `AsyncLoading` on its very first read even with
    // nothing real to await, since the framework always defers through at
    // least one microtask. `CompleteProfileScreen` is reached immediately
    // after OTP verification and is plausibly the very first place in the
    // session that reads `authControllerProvider` — a fast/programmatic
    // submit right after navigating here could otherwise see a null
    // `.value` and report a spurious "unauthorized" for a genuinely
    // signed-in user.
    String? userId;
    try {
      userId = (await ref.read(authControllerProvider.future))?.id;
    } catch (_) {
      userId = null;
    }
    if (userId == null) {
      state = const IdentityDetailsSubmitFailed(AuthFailure('unauthorized'));
      return;
    }

    state = const IdentityDetailsSubmitting();
    try {
      await ref.read(identityDetailsRepositoryProvider).submit(
            userId: userId,
            surname: surname,
            givenName: givenName,
            registerNumber: registerNumber,
          );

      // Best-effort: seed the public display name from нэр if the
      // profile doesn't already have a custom one — a blank display name
      // otherwise reads badly across the app (home greeting, asset
      // cards, chat, ...). Never overwrites a name the user already set
      // themselves, and a failure here doesn't undo the registration
      // step that already succeeded.
      final String? currentDisplayName = ref.read(authControllerProvider).value?.displayName?.trim();
      if (currentDisplayName == null || currentDisplayName.isEmpty) {
        try {
          await ref.read(profileRepositoryProvider).updateDisplayName(
                userId: userId,
                displayName: givenName,
              );
        } catch (_) {
          // Non-critical — swallow and continue.
        }
      }

      // Lets the router's redirect (which awaits this same provider) see
      // the fresh `true` on the very next navigation instead of the
      // cached pre-submit `false`.
      ref.invalidate(identityDetailsCompletedProvider(userId));
      state = const IdentityDetailsSubmitted();
    } catch (e) {
      state = IdentityDetailsSubmitFailed(Failure.from(e));
    }
  }

  void reset() => state = const IdentityDetailsIdle();
}

final NotifierProvider<IdentityDetailsController, IdentityDetailsSubmitState>
    identityDetailsControllerProvider =
    NotifierProvider<IdentityDetailsController, IdentityDetailsSubmitState>(
  IdentityDetailsController.new,
);
