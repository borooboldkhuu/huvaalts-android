import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../disputes/domain/entities/dispute.dart';
import '../../../disputes/domain/entities/dispute_status.dart';
import 'admin_providers.dart';

class DisputeResolutionState {
  const DisputeResolutionState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Resolving here relies entirely on the existing
/// `restore_booking_status_after_dispute_resolution` trigger (Phase 9)
/// to restore the booking's pre-dispute status and notify both
/// participants — this controller (and the RPC it calls) does nothing
/// beyond the status/notes update and audit log.
class DisputeResolutionController extends Notifier<DisputeResolutionState> {
  @override
  DisputeResolutionState build() => const DisputeResolutionState();

  Future<Dispute> resolve({
    required String disputeId,
    required DisputeStatus newStatus,
    String? resolutionNotes,
  }) async {
    state = const DisputeResolutionState(isSubmitting: true);
    try {
      final Dispute result = await ref.read(adminRepositoryProvider).resolveDispute(
            disputeId: disputeId,
            newStatus: newStatus,
            resolutionNotes: resolutionNotes,
          );
      ref.invalidate(adminOpenDisputesProvider);
      return result;
    } finally {
      state = const DisputeResolutionState(isSubmitting: false);
    }
  }
}

final NotifierProvider<DisputeResolutionController, DisputeResolutionState>
    disputeResolutionControllerProvider =
    NotifierProvider<DisputeResolutionController, DisputeResolutionState>(
        DisputeResolutionController.new);
