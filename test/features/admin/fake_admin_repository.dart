import 'package:huvalts/shared/entities/app_banner.dart';
import 'package:huvalts/features/admin/domain/entities/asset_moderation_summary.dart';
import 'package:huvalts/features/admin/domain/entities/platform_settings.dart';
import 'package:huvalts/features/admin/domain/entities/promotion.dart';
import 'package:huvalts/features/admin/domain/entities/report.dart';
import 'package:huvalts/features/admin/domain/entities/report_status.dart';
import 'package:huvalts/features/admin/domain/entities/wire_topup_reconciliation_result.dart';
import 'package:huvalts/features/admin/domain/repositories/admin_repository.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute.dart';
import 'package:huvalts/features/disputes/domain/entities/dispute_status.dart';
import 'package:huvalts/features/wallet/domain/entities/payout.dart';
import 'package:huvalts/features/wallet/domain/entities/payout_status.dart';

/// One shared fake, unlike most other features' tests (which each define
/// a small local `_FakeXRepository`) — `AdminRepository` has a dozen
/// methods across five unrelated queues, and five near-identical
/// 12-method fakes would be pure duplication with no test-clarity
/// benefit. Every method not exercised by a given test throws
/// [UnimplementedError] by default, so a test that calls something it
/// didn't set up a result for fails loudly rather than silently returning
/// a meaningless default.
class FakeAdminRepository implements AdminRepository {
  bool isAdminResult = true;

  String? lastApprovedAssetId;
  AssetModerationSummary? approveResult;

  String? lastRejectedAssetId;
  String? lastRejectReason;
  AssetModerationSummary? rejectResult;

  String? lastSuspendedAssetId;
  String? lastSuspendReason;
  AssetModerationSummary? suspendResult;

  String? lastProcessedPayoutId;
  PayoutStatus? lastProcessedStatus;
  String? lastDestinationReference;
  Payout? processPayoutResult;

  String? lastResolvedDisputeId;
  DisputeStatus? lastDisputeStatus;
  String? lastResolutionNotes;
  Dispute? resolveDisputeResult;

  String? lastResolvedReportId;
  ReportStatus? lastReportStatus;
  Report? resolveReportResult;

  double? lastCommissionPercent;
  PlatformSettings? updateCommissionResult;

  String? lastUpsertedPromotionId;
  String? lastUpsertedPromotionTitle;
  Promotion? upsertPromotionResult;

  String? lastDeactivatedPromotionId;
  Promotion? deactivatePromotionResult;

  String? lastRefundedBookingId;
  String? lastRefundReason;

  int reconcileWireTopupsCallCount = 0;
  WireTopupReconciliationResult? reconcileWireTopupsResult;

  Object? errorToThrow;

  @override
  Future<bool> isCurrentUserAdmin() async {
    if (errorToThrow != null) throw errorToThrow!;
    return isAdminResult;
  }

  @override
  Future<List<AssetModerationSummary>> getPendingAssets() async {
    throw UnimplementedError();
  }

  @override
  Future<AssetModerationSummary> approveAsset(String assetId) async {
    lastApprovedAssetId = assetId;
    if (errorToThrow != null) throw errorToThrow!;
    return approveResult!;
  }

  @override
  Future<AssetModerationSummary> rejectAsset({required String assetId, required String reason}) async {
    lastRejectedAssetId = assetId;
    lastRejectReason = reason;
    if (errorToThrow != null) throw errorToThrow!;
    return rejectResult!;
  }

  @override
  Future<AssetModerationSummary> suspendAsset({required String assetId, required String reason}) async {
    lastSuspendedAssetId = assetId;
    lastSuspendReason = reason;
    if (errorToThrow != null) throw errorToThrow!;
    return suspendResult!;
  }

  @override
  Future<List<Payout>> getPendingPayouts() async {
    throw UnimplementedError();
  }

  @override
  Future<Payout> processPayout({
    required String payoutId,
    required PayoutStatus newStatus,
    String? destinationReference,
  }) async {
    lastProcessedPayoutId = payoutId;
    lastProcessedStatus = newStatus;
    lastDestinationReference = destinationReference;
    if (errorToThrow != null) throw errorToThrow!;
    return processPayoutResult!;
  }

  @override
  Future<List<Dispute>> getOpenDisputes() async {
    throw UnimplementedError();
  }

  @override
  Future<Dispute> resolveDispute({
    required String disputeId,
    required DisputeStatus newStatus,
    String? resolutionNotes,
  }) async {
    lastResolvedDisputeId = disputeId;
    lastDisputeStatus = newStatus;
    lastResolutionNotes = resolutionNotes;
    if (errorToThrow != null) throw errorToThrow!;
    return resolveDisputeResult!;
  }

  @override
  Future<List<Report>> getOpenReports() async {
    throw UnimplementedError();
  }

  @override
  Future<Report> resolveReport({required String reportId, required ReportStatus newStatus}) async {
    lastResolvedReportId = reportId;
    lastReportStatus = newStatus;
    if (errorToThrow != null) throw errorToThrow!;
    return resolveReportResult!;
  }

  @override
  Future<PlatformSettings> getPlatformSettings() async {
    throw UnimplementedError();
  }

  @override
  Future<PlatformSettings> updateCommissionPercent(double percent) async {
    lastCommissionPercent = percent;
    if (errorToThrow != null) throw errorToThrow!;
    return updateCommissionResult!;
  }

  @override
  Future<List<Promotion>> getPromotions() async {
    throw UnimplementedError();
  }

  @override
  Future<Promotion> upsertPromotion({
    String? id,
    String? code,
    required String title,
    String? description,
    double? discountPercent,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
  }) async {
    lastUpsertedPromotionId = id;
    lastUpsertedPromotionTitle = title;
    if (errorToThrow != null) throw errorToThrow!;
    return upsertPromotionResult!;
  }

  @override
  Future<Promotion> deactivatePromotion(String id) async {
    lastDeactivatedPromotionId = id;
    if (errorToThrow != null) throw errorToThrow!;
    return deactivatePromotionResult!;
  }

  @override
  Future<void> refundBookingPayment({required String bookingId, String? reason}) async {
    lastRefundedBookingId = bookingId;
    lastRefundReason = reason;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<WireTopupReconciliationResult> reconcileWireTopups() async {
    reconcileWireTopupsCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return reconcileWireTopupsResult ?? const WireTopupReconciliationResult(checked: 0, credited: 0, markedFailed: 0);
  }
  @override
  Future<List<AppBanner>> getAppBanners() async => throw UnimplementedError();

  @override
  Future<AppBanner> upsertAppBanner({
    String? id,
    required String storagePath,
    required int sortOrder,
    required bool isActive,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteAppBanner(String id) async => throw UnimplementedError();
}
