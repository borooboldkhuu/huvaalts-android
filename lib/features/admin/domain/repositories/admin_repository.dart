import '../../../../shared/entities/app_banner.dart';
import '../../../disputes/domain/entities/dispute.dart';
import '../../../disputes/domain/entities/dispute_status.dart';
import '../../../wallet/domain/entities/payout.dart';
import '../../../wallet/domain/entities/payout_status.dart';
import '../entities/asset_moderation_summary.dart';
import '../entities/platform_settings.dart';
import '../entities/promotion.dart';
import '../entities/report.dart';
import '../entities/report_status.dart';
import '../entities/wire_topup_reconciliation_result.dart';

/// Backs the admin dashboard (spec sections 22, 29, 30, 34 — Phase 11).
/// Every method here maps to a `SECURITY DEFINER` RPC in
/// `supabase/migrations/0012_admin_dashboard.sql` that re-checks
/// `is_admin(auth.uid())` itself — [isCurrentUserAdmin] and this whole
/// feature's route gating are a UX convenience only, never the actual
/// authorization boundary (spec section 34: never trust the client).
///
/// Reuses [Dispute]/[Payout] straight from the disputes/wallet features
/// rather than declaring admin-only duplicates of them: the resolving/
/// processing RPCs return the exact same `disputes`/`payouts` row shape
/// those features already model, so a second parallel entity would just
/// be duplication with no behavioral difference.
abstract interface class AdminRepository {
  /// Client-side convenience check against `admin_users` (RLS-gated —
  /// returns empty, not an error, for a non-admin). Used only to decide
  /// whether to show admin navigation; every actual admin RPC re-checks
  /// server-side regardless of what this returns.
  Future<bool> isCurrentUserAdmin();

  /// Assets an admin can currently act on: `pendingReview` (new listings
  /// awaiting first approval) and `published` (already-live listings that
  /// could be suspended), newest first.
  Future<List<AssetModerationSummary>> getPendingAssets();

  Future<AssetModerationSummary> approveAsset(String assetId);

  Future<AssetModerationSummary> rejectAsset({required String assetId, required String reason});

  Future<AssetModerationSummary> suspendAsset({required String assetId, required String reason});

  /// Payouts still awaiting action: `pending` or `processing`.
  Future<List<Payout>> getPendingPayouts();

  Future<Payout> processPayout({
    required String payoutId,
    required PayoutStatus newStatus,
    String? destinationReference,
  });

  /// Disputes not yet finally resolved: `open`, `underReview`, `escalated`.
  Future<List<Dispute>> getOpenDisputes();

  Future<Dispute> resolveDispute({
    required String disputeId,
    required DisputeStatus newStatus,
    String? resolutionNotes,
  });

  /// Reverses a paid booking's payment via `admin_refund_booking_payment`
  /// (`0018_security_and_consistency_hardening.sql`) — claws back the
  /// owner's share (from `pending_balance`, then `available_balance` if
  /// it was already released) and credits the renter's full payment back
  /// to their `available_balance`. This is a separate, explicit admin
  /// action from [resolveDispute] — not every dispute resolves in the
  /// renter's favor, so resolving a dispute never refunds automatically.
  /// Throws a [ConflictException] (message `owner_balance_insufficient_
  /// for_reversal`) if the owner has already withdrawn the money via a
  /// payout — that case needs manual reconciliation outside the app.
  Future<void> refundBookingPayment({required String bookingId, String? reason});

  /// Reports still awaiting action: `open`.
  Future<List<Report>> getOpenReports();

  Future<Report> resolveReport({required String reportId, required ReportStatus newStatus});

  Future<PlatformSettings> getPlatformSettings();

  Future<PlatformSettings> updateCommissionPercent(double percent);

  /// Every promotion, active or not — unlike the other queues above this
  /// isn't filtered to "needs action", since there's no action-needed
  /// state for a promotion the way there is for a pending asset or an
  /// open dispute; an admin managing promotions wants to see all of them.
  /// Newest-created first.
  Future<List<Promotion>> getPromotions();

  /// Creates a new promotion when [id] is null, otherwise updates the
  /// existing one — see `admin_upsert_promotion`
  /// (`0013_security_perf_hardening.sql`) for why this is one RPC rather
  /// than separate create/update calls.
  Future<Promotion> upsertPromotion({
    String? id,
    String? code,
    required String title,
    String? description,
    double? discountPercent,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
  });

  Future<Promotion> deactivatePromotion(String id);

  /// Triggers the `reconcile-wire-topups` Edge Function on demand — the
  /// manual counterpart to whatever schedule (if any) the deployment has
  /// set up for it (see that function's header comment). Checks
  /// stale-`pending` `wallet_topups` rows against wire.mn's own
  /// PaymentIntent status and credits/fails each one accordingly; safe
  /// to call repeatedly (idempotent — a row already resolved by a
  /// scheduled run or a late webhook is simply left alone).
  Future<WireTopupReconciliationResult> reconcileWireTopups();

  /// Every banner, active or not — same "admin managing content wants to
  /// see everything" reasoning as [getPromotions]. Sorted by
  /// `sort_order` (display order), not recency.
  Future<List<AppBanner>> getAppBanners();

  /// Creates a new banner when [id] is null, otherwise updates the
  /// existing row's image/order/active state — see
  /// `admin_upsert_app_banner` (`0023_app_banners.sql`). [storagePath] is
  /// the path already-uploaded to the `app-banners` bucket (this method
  /// doesn't upload — that's `AdminBannerFormController.pickAndSubmit`'s
  /// job, mirroring how `AssetCreateController` uploads before calling
  /// `createAsset`).
  Future<AppBanner> upsertAppBanner({
    String? id,
    required String storagePath,
    required int sortOrder,
    required bool isActive,
  });

  /// Hard-deletes a banner row (see `admin_delete_app_banner`'s doc
  /// comment for why this is a real delete, unlike
  /// [deactivatePromotion]'s soft one).
  Future<void> deleteAppBanner(String id);
}
