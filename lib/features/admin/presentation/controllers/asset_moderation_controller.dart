import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/asset_moderation_summary.dart';
import 'admin_providers.dart';

class AssetModerationState {
  const AssetModerationState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Approve/reject/suspend actions for the moderation queue
/// (`AdminAssetModerationScreen`). Mirrors `RequestPayoutController` — a
/// small action-only controller, unit-testable against a fake
/// `AdminRepository` without pumping a widget tree. Invalidates
/// [pendingAssetsProvider] on success so the queue re-fetches rather than
/// trying to patch one row in cached list state by hand.
class AssetModerationController extends Notifier<AssetModerationState> {
  @override
  AssetModerationState build() => const AssetModerationState();

  Future<AssetModerationSummary> approve(String assetId) async {
    state = const AssetModerationState(isSubmitting: true);
    try {
      final AssetModerationSummary result =
          await ref.read(adminRepositoryProvider).approveAsset(assetId);
      ref.invalidate(pendingAssetsProvider);
      return result;
    } finally {
      state = const AssetModerationState(isSubmitting: false);
    }
  }

  Future<AssetModerationSummary> reject({required String assetId, required String reason}) async {
    state = const AssetModerationState(isSubmitting: true);
    try {
      final AssetModerationSummary result =
          await ref.read(adminRepositoryProvider).rejectAsset(assetId: assetId, reason: reason);
      ref.invalidate(pendingAssetsProvider);
      return result;
    } finally {
      state = const AssetModerationState(isSubmitting: false);
    }
  }

  Future<AssetModerationSummary> suspend({required String assetId, required String reason}) async {
    state = const AssetModerationState(isSubmitting: true);
    try {
      final AssetModerationSummary result =
          await ref.read(adminRepositoryProvider).suspendAsset(assetId: assetId, reason: reason);
      ref.invalidate(pendingAssetsProvider);
      return result;
    } finally {
      state = const AssetModerationState(isSubmitting: false);
    }
  }
}

final NotifierProvider<AssetModerationController, AssetModerationState> assetModerationControllerProvider =
    NotifierProvider<AssetModerationController, AssetModerationState>(AssetModerationController.new);
