import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/payout.dart';
import 'wallet_providers.dart';

class RequestPayoutState {
  const RequestPayoutState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Mirrors `BookingRequestController` — a small action-only controller so
/// the submit-in-flight/success/failure paths are unit-testable against a
/// fake `WalletRepository` without pumping a widget tree.
class RequestPayoutController extends Notifier<RequestPayoutState> {
  @override
  RequestPayoutState build() => const RequestPayoutState();

  Future<Payout> submit({required double amount}) async {
    state = const RequestPayoutState(isSubmitting: true);
    try {
      final Payout payout = await ref.read(walletRepositoryProvider).requestPayout(amount: amount);
      return payout;
    } finally {
      state = const RequestPayoutState(isSubmitting: false);
    }
  }
}

final NotifierProvider<RequestPayoutController, RequestPayoutState> requestPayoutControllerProvider =
    NotifierProvider<RequestPayoutController, RequestPayoutState>(RequestPayoutController.new);
