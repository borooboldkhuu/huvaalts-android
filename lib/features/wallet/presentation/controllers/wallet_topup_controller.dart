import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/wallet_topup.dart';
import '../../domain/entities/wallet_topup_status.dart';
import '../../domain/repositories/wallet_topup_repository.dart';
import 'wallet_providers.dart';

enum WalletTopupStep { idle, creating, awaitingPayment, checking, succeeded, failed }

class WalletTopupState {
  const WalletTopupState({this.step = WalletTopupStep.idle, this.start, this.error});

  final WalletTopupStep step;
  final WalletTopupStart? start;

  /// Same "raw thrown object, mapped to copy only at the UI layer"
  /// convention as `VerificationState.error`.
  final Object? error;

  WalletTopupState copyWith({WalletTopupStep? step, WalletTopupStart? start, Object? error}) {
    return WalletTopupState(step: step ?? this.step, start: start ?? this.start, error: error);
  }
}

/// Drives the wallet top-up sheet: create a wire.mn PaymentIntent +
/// checkout session (or, in mock mode, a self-completable stand-in) via
/// `wire-topup`, then poll `wallet_topups` until the webhook (or, in mock
/// mode, `mockComplete`) has marked it `paid`. Mirrors
/// `VerificationController`'s shape closely — same kind of "start an
/// external step, then poll for the backend's own verdict" flow.
class WalletTopupController extends Notifier<WalletTopupState> {
  static const int _maxPollAttempts = 20;
  static const Duration _pollDelay = Duration(seconds: 3);

  @override
  WalletTopupState build() => const WalletTopupState();

  Future<void> create(double amountMnt) async {
    state = const WalletTopupState(step: WalletTopupStep.creating);
    try {
      final WalletTopupStart start =
          await ref.read(walletTopupRepositoryProvider).create(amountMnt: amountMnt);
      state = WalletTopupState(step: WalletTopupStep.awaitingPayment, start: start);
    } catch (e) {
      state = WalletTopupState(step: WalletTopupStep.failed, error: e);
    }
  }

  /// One status check — called by the sheet's own periodic timer and by
  /// its manual "Шалгах" button alike, so both paths share exactly the
  /// same terminal-state logic.
  Future<void> checkOnce() async {
    final WalletTopupStart? start = state.start;
    if (start == null) return;
    state = state.copyWith(step: WalletTopupStep.checking);
    try {
      final WalletTopup? topup = await ref.read(walletTopupRepositoryProvider).getById(start.topup.id);
      if (topup == null) {
        state = state.copyWith(step: WalletTopupStep.awaitingPayment);
        return;
      }
      switch (topup.status) {
        case WalletTopupStatus.paid:
          state = state.copyWith(step: WalletTopupStep.succeeded);
          await _invalidateWalletReads();
        case WalletTopupStatus.failed:
        case WalletTopupStatus.cancelled:
          state = state.copyWith(step: WalletTopupStep.failed);
        case WalletTopupStatus.pending:
          state = state.copyWith(step: WalletTopupStep.awaitingPayment);
      }
    } catch (e) {
      // A single failed status check shouldn't end the flow — network
      // blips during polling are expected; stay in awaitingPayment so the
      // timer/manual button can just try again.
      state = state.copyWith(step: WalletTopupStep.awaitingPayment);
    }
  }

  /// Bounded auto-poll — same reasoning as
  /// `VerificationController.confirmConsentAndPoll`: don't spin forever
  /// if the webhook never arrives. The sheet also offers a manual check
  /// so the user isn't stuck once this gives up.
  Future<void> pollUntilSettled() async {
    for (int attempt = 0; attempt < _maxPollAttempts; attempt++) {
      await checkOnce();
      if (state.step == WalletTopupStep.succeeded || state.step == WalletTopupStep.failed) return;
      if (attempt < _maxPollAttempts - 1) {
        await Future<void>.delayed(_pollDelay);
      }
    }
  }

  Future<void> mockComplete() async {
    final WalletTopupStart? start = state.start;
    if (start == null) return;
    state = state.copyWith(step: WalletTopupStep.checking);
    try {
      final WalletTopup updated = await ref.read(walletTopupRepositoryProvider).mockComplete(start.topup.id);
      if (updated.status == WalletTopupStatus.paid) {
        state = state.copyWith(step: WalletTopupStep.succeeded);
        await _invalidateWalletReads();
      } else {
        state = state.copyWith(step: WalletTopupStep.failed);
      }
    } catch (e) {
      state = state.copyWith(step: WalletTopupStep.failed, error: e);
    }
  }

  /// Reads `authControllerProvider` via `.future` rather than a
  /// synchronous `.value` — same reasoning as
  /// `VerificationController.start()`/`IdentityDetailsController.submit()`
  /// (an `AsyncNotifier` can still be `AsyncLoading` on its very first
  /// read, which would otherwise skip this cache invalidation for no
  /// reason right when it matters most — immediately after a top-up
  /// actually succeeds). Errors are swallowed either way: a failed/slow
  /// auth read here should only mean the wallet screen doesn't
  /// auto-refresh immediately, never fail the top-up flow itself, whose
  /// own success/failure was already decided by the caller before this
  /// runs.
  Future<void> _invalidateWalletReads() async {
    String? userId;
    try {
      userId = (await ref.read(authControllerProvider.future))?.id;
    } catch (_) {
      userId = null;
    }
    if (userId == null) return;
    ref.invalidate(walletProvider(userId));
    ref.invalidate(walletTransactionsProvider(userId));
  }

  void reset() => state = const WalletTopupState();
}

final NotifierProvider<WalletTopupController, WalletTopupState> walletTopupControllerProvider =
    NotifierProvider<WalletTopupController, WalletTopupState>(WalletTopupController.new);
