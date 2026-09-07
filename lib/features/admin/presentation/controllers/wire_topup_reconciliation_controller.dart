import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/wire_topup_reconciliation_result.dart';
import 'admin_providers.dart';

sealed class WireTopupReconciliationState {
  const WireTopupReconciliationState();
}

class WireTopupReconciliationIdle extends WireTopupReconciliationState {
  const WireTopupReconciliationIdle();
}

class WireTopupReconciliationInProgress extends WireTopupReconciliationState {
  const WireTopupReconciliationInProgress();
}

class WireTopupReconciliationDone extends WireTopupReconciliationState {
  const WireTopupReconciliationDone(this.result);

  final WireTopupReconciliationResult result;
}

class WireTopupReconciliationFailed extends WireTopupReconciliationState {
  const WireTopupReconciliationFailed(this.error);

  final Object error;
}

/// Drives the admin "Wire дахин шалгах" (reconcile wire.mn top-ups)
/// dashboard action — a single-shot call to
/// `AdminRepository.reconcileWireTopups`, same single-shot shape as
/// `BookingRefundController`/`ReportController`.
class WireTopupReconciliationController extends Notifier<WireTopupReconciliationState> {
  @override
  WireTopupReconciliationState build() => const WireTopupReconciliationIdle();

  Future<void> reconcile() async {
    state = const WireTopupReconciliationInProgress();
    try {
      final WireTopupReconciliationResult result =
          await ref.read(adminRepositoryProvider).reconcileWireTopups();
      state = WireTopupReconciliationDone(result);
    } catch (error) {
      state = WireTopupReconciliationFailed(error);
    }
  }

  void reset() => state = const WireTopupReconciliationIdle();
}

final NotifierProvider<WireTopupReconciliationController, WireTopupReconciliationState>
    wireTopupReconciliationControllerProvider =
    NotifierProvider<WireTopupReconciliationController, WireTopupReconciliationState>(
  WireTopupReconciliationController.new,
);
