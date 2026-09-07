import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/identity_verification_repository.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';

enum VerificationStep { idle, startingSession, awaitingConsent, polling, verified, failed }

/// Thrown by [VerificationController] itself (never by the repository) for
/// the two outcomes that aren't really "an error talking to the backend"
/// so much as "the backend answered, and the answer wasn't verified" —
/// kept as their own types (rather than a raw string) so the screen can
/// pattern-match them the same way it pattern-matches [AppException]
/// subtypes via [Failure.from].
class VerificationTimeoutException implements Exception {
  const VerificationTimeoutException();
}

class VerificationNotCompletedException implements Exception {
  const VerificationNotCompletedException();
}

class VerificationState {
  const VerificationState({
    this.step = VerificationStep.idle,
    this.session,
    this.error,
  });

  final VerificationStep step;
  final DanVerificationSession? session;

  /// The raw thrown object (an [AppException], a
  /// [VerificationTimeoutException]/[VerificationNotCompletedException],
  /// or anything else) — never pre-rendered to text here. The screen maps
  /// it to copy via `Failure.from` + `failurePresentation`, same as every
  /// other controller in this project.
  final Object? error;

  VerificationState copyWith({
    VerificationStep? step,
    DanVerificationSession? session,
    Object? error,
    bool clearError = false,
  }) {
    return VerificationState(
      step: step ?? this.step,
      session: session ?? this.session,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the "Get verified" flow (spec section 9): start a DAN session,
/// let the user complete consent (mock or real — see
/// `verification_screen.dart`), then poll until the backend reports
/// `verified` (or gives up). Kept as its own `Notifier` rather than
/// inline widget state (unlike `PaymentSection`) because polling has real
/// branching logic worth unit-testing against a fake repository, the same
/// reasoning that gave booking its own `BookingRequestController`.
class VerificationController extends Notifier<VerificationState> {
  static const int _maxPollAttempts = 5;
  static const Duration _pollDelay = Duration(milliseconds: 600);

  @override
  VerificationState build() => const VerificationState();

  Future<void> start() async {
    // Reads through AuthController (an AuthRepository-backed AsyncNotifier)
    // rather than the Supabase client directly, so this controller stays
    // testable against a fake AuthRepository — the same reasoning behind
    // every other repository interface in this project. Awaits `.future`
    // rather than reading `.value` synchronously: an `AsyncNotifier`'s
    // state can still be `AsyncLoading` on its very first read even when
    // its `build()` has nothing to actually await, since the notifier
    // framework always defers through at least one microtask — `.value`
    // would come back null in that split second and misreport "signed
    // out". By the time a real user reaches this screen `authControllerProvider`
    // has long since resolved elsewhere in the app, but a fresh
    // `ProviderContainer` in a test does not have that head start.
    AppUser? user;
    try {
      user = await ref.read(authControllerProvider.future);
    } catch (_) {
      user = null;
    }
    final String? userId = user?.id;
    if (userId == null) {
      state = state.copyWith(
        step: VerificationStep.failed,
        error: const UnauthorizedException(),
      );
      return;
    }
    state = state.copyWith(step: VerificationStep.startingSession, clearError: true);
    try {
      final DanVerificationSession session = await ref
          .read(identityVerificationRepositoryProvider)
          .startVerification(userId: userId);
      state = VerificationState(step: VerificationStep.awaitingConsent, session: session);
    } catch (e) {
      state = VerificationState(step: VerificationStep.failed, error: e);
    }
  }

  /// Called once the user says they've completed consent (tapped through
  /// the mock sheet, or came back from the real DAN browser flow). Polls
  /// a bounded number of times rather than forever, so a session that
  /// never settles doesn't spin the UI indefinitely.
  Future<void> confirmConsentAndPoll() async {
    final DanVerificationSession? session = state.session;
    if (session == null) return;

    state = state.copyWith(step: VerificationStep.polling, clearError: true);
    for (int attempt = 0; attempt < _maxPollAttempts; attempt++) {
      try {
        final DanVerificationStatus status = await ref
            .read(identityVerificationRepositoryProvider)
            .checkStatus(sessionId: session.sessionId);
        if (status == DanVerificationStatus.verified) {
          state = state.copyWith(step: VerificationStep.verified);
          return;
        }
        if (status == DanVerificationStatus.failed || status == DanVerificationStatus.cancelled) {
          state = state.copyWith(
            step: VerificationStep.failed,
            error: const VerificationNotCompletedException(),
          );
          return;
        }
      } catch (e) {
        state = state.copyWith(step: VerificationStep.failed, error: e);
        return;
      }
      if (attempt < _maxPollAttempts - 1) {
        await Future<void>.delayed(_pollDelay);
      }
    }
    state = state.copyWith(
      step: VerificationStep.failed,
      error: const VerificationTimeoutException(),
    );
  }

  void reset() => state = const VerificationState();
}

final NotifierProvider<VerificationController, VerificationState> verificationControllerProvider =
    NotifierProvider<VerificationController, VerificationState>(VerificationController.new);
