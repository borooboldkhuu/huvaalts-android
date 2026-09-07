import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../wallet/domain/entities/payout.dart';
import '../../../wallet/domain/entities/payout_status.dart';
import 'admin_providers.dart';

class PayoutProcessingState {
  const PayoutProcessingState({this.isSubmitting = false});

  final bool isSubmitting;
}

class PayoutProcessingController extends Notifier<PayoutProcessingState> {
  @override
  PayoutProcessingState build() => const PayoutProcessingState();

  Future<Payout> process({
    required String payoutId,
    required PayoutStatus newStatus,
    String? destinationReference,
  }) async {
    state = const PayoutProcessingState(isSubmitting: true);
    try {
      final Payout result = await ref.read(adminRepositoryProvider).processPayout(
            payoutId: payoutId,
            newStatus: newStatus,
            destinationReference: destinationReference,
          );
      ref.invalidate(adminPendingPayoutsProvider);
      return result;
    } finally {
      state = const PayoutProcessingState(isSubmitting: false);
    }
  }
}

final NotifierProvider<PayoutProcessingController, PayoutProcessingState>
    payoutProcessingControllerProvider =
    NotifierProvider<PayoutProcessingController, PayoutProcessingState>(PayoutProcessingController.new);
