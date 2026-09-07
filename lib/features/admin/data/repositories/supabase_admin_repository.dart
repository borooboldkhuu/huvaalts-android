import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../shared/entities/app_banner.dart';
import '../../../assets/domain/entities/asset_status.dart';
import '../../../disputes/domain/entities/dispute.dart';
import '../../../disputes/domain/entities/dispute_category.dart';
import '../../../disputes/domain/entities/dispute_status.dart';
import '../../../wallet/domain/entities/payout.dart';
import '../../../wallet/domain/entities/payout_status.dart';
import '../../domain/entities/asset_moderation_summary.dart';
import '../../domain/entities/platform_settings.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/report_status.dart';
import '../../domain/entities/report_target_type.dart';
import '../../domain/entities/wire_topup_reconciliation_result.dart';
import '../../domain/repositories/admin_repository.dart';

/// Talks to the RPCs and tables added in
/// `supabase/migrations/0012_admin_dashboard.sql`. Every mutating method
/// here calls the matching `security definer` RPC (never writes to
/// `assets`/`payouts`/`disputes`/`reports` directly) — the RPCs are the
/// only path left that can move those rows through admin-only
/// transitions, and each one logs to `audit_logs` on the server side by
/// itself, so there's nothing for this class to log separately.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  static const String _assetCardsView = 'asset_cards';

  @override
  Future<bool> isCurrentUserAdmin() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final Map<String, dynamic>? row =
          await _client.from('admin_users').select('user_id').eq('user_id', userId).maybeSingle();
      return row != null;
    } on PostgrestException {
      // RLS returning nothing for a non-admin looks like "no row", not an
      // error — but if something else goes wrong here, fail closed rather
      // than accidentally showing admin navigation.
      return false;
    }
  }

  // -- Asset moderation ---------------------------------------------------

  @override
  Future<List<AssetModerationSummary>> getPendingAssets() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from(_assetCardsView)
          .select()
          .inFilter('status', ['pending_review', 'published'])
          .order('created_at', ascending: false);
      return rows.map(_assetFromCardRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<AssetModerationSummary> approveAsset(String assetId) async {
    try {
      await _client.rpc<dynamic>('admin_approve_asset', params: {'p_asset_id': assetId});
      // Must `await` (not just `return`) — otherwise a `PostgrestException`
      // thrown while re-fetching happens after control has already left
      // this `try` block, so the `catch` below would never map it.
      return await _reloadAssetSummary(assetId);
    } on PostgrestException catch (e) {
      throw _mapAssetActionError(e);
    }
  }

  @override
  Future<AssetModerationSummary> rejectAsset({required String assetId, required String reason}) async {
    try {
      await _client.rpc<dynamic>('admin_reject_asset', params: {'p_asset_id': assetId, 'p_reason': reason});
      return await _reloadAssetSummary(assetId);
    } on PostgrestException catch (e) {
      throw _mapAssetActionError(e);
    }
  }

  @override
  Future<AssetModerationSummary> suspendAsset({required String assetId, required String reason}) async {
    try {
      await _client.rpc<dynamic>('admin_suspend_asset', params: {'p_asset_id': assetId, 'p_reason': reason});
      return await _reloadAssetSummary(assetId);
    } on PostgrestException catch (e) {
      throw _mapAssetActionError(e);
    }
  }

  /// The moderation RPCs return a bare `public.assets` row, missing the
  /// `asset_cards` view's computed/joined columns (`owner_display_name`,
  /// `display_price`, `primary_image_path`) this summary needs — so,
  /// same reasoning as `SupabaseBookingRepository.createBooking`
  /// re-fetching through `booking_cards` after its RPC, re-query the view
  /// by id rather than trying to reconstruct those fields by hand.
  Future<AssetModerationSummary> _reloadAssetSummary(String assetId) async {
    final Map<String, dynamic>? row =
        await _client.from(_assetCardsView).select().eq('id', assetId).maybeSingle();
    if (row == null) {
      throw const UnknownException(message: 'asset_updated_but_not_found');
    }
    return _assetFromCardRow(row);
  }

  AppException _mapAssetActionError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'reason_required' => const ValidationException(message: 'reason_required'),
      'asset_not_pending_review' => const ConflictException(message: 'asset_not_pending_review'),
      'asset_not_published' => const ConflictException(message: 'asset_not_published'),
      'asset_not_rejected' => const ConflictException(message: 'asset_not_rejected'),
      'auth_required' => const UnauthorizedException(message: 'auth_required'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  AssetModerationSummary _assetFromCardRow(Map<String, dynamic> row) {
    return AssetModerationSummary(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      ownerDisplayName: row['owner_display_name'] as String? ?? '',
      title: row['title'] as String,
      status: AssetStatus.fromId(row['status'] as String),
      moderationNote: row['moderation_note'] as String?,
      primaryImagePath: row['primary_image_path'] as String?,
      displayPrice: (row['display_price'] as num?)?.toDouble(),
      currency: row['currency'] as String? ?? 'MNT',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // -- Payouts --------------------------------------------------------

  @override
  Future<List<Payout>> getPendingPayouts() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('payouts')
          .select()
          .inFilter('status', ['pending', 'processing'])
          .order('requested_at', ascending: false);
      return rows.map(_payoutFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Payout> processPayout({
    required String payoutId,
    required PayoutStatus newStatus,
    String? destinationReference,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'p_payout_id': payoutId,
        'p_new_status': newStatus.id,
      };
      if (destinationReference != null) params['p_destination_reference'] = destinationReference;
      final dynamic response = await _client.rpc<dynamic>('admin_process_payout', params: params);
      return _payoutFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapPayoutError(e);
    }
  }

  AppException _mapPayoutError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'invalid_status' => const ValidationException(message: 'invalid_status'),
      'payout_not_found' => const NotFoundException(message: 'not_found'),
      'invalid_status_transition' => const ConflictException(message: 'invalid_status_transition'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Payout _payoutFromRow(Map<String, dynamic> row) {
    return Payout(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      amount: (row['amount'] as num).toDouble(),
      status: PayoutStatus.fromId(row['status'] as String),
      destinationReference: row['destination_reference'] as String?,
      requestedAt: DateTime.parse(row['requested_at'] as String),
      processedAt:
          row['processed_at'] != null ? DateTime.parse(row['processed_at'] as String) : null,
    );
  }

  // -- Disputes ---------------------------------------------------------

  @override
  Future<List<Dispute>> getOpenDisputes() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('disputes')
          .select()
          .inFilter('status', ['open', 'under_review', 'escalated'])
          .order('created_at', ascending: false);
      return rows.map(_disputeFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Dispute> resolveDispute({
    required String disputeId,
    required DisputeStatus newStatus,
    String? resolutionNotes,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'p_dispute_id': disputeId,
        'p_new_status': newStatus.id,
      };
      if (resolutionNotes != null) params['p_resolution_notes'] = resolutionNotes;
      final dynamic response = await _client.rpc<dynamic>('admin_resolve_dispute', params: params);
      return _disputeFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapDisputeError(e);
    }
  }

  AppException _mapDisputeError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'invalid_status' => const ValidationException(message: 'invalid_status'),
      'dispute_not_found' => const NotFoundException(message: 'not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  @override
  Future<void> refundBookingPayment({required String bookingId, String? reason}) async {
    try {
      final Map<String, dynamic> params = {'p_booking_id': bookingId};
      if (reason != null) params['p_reason'] = reason;
      await _client.rpc<dynamic>('admin_refund_booking_payment', params: params);
    } on PostgrestException catch (e) {
      throw _mapRefundError(e);
    }
  }

  AppException _mapRefundError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'booking_not_found' => const NotFoundException(message: 'not_found'),
      'no_paid_payment' => const ValidationException(message: 'no_paid_payment'),
      'already_refunded' => const ConflictException(message: 'already_refunded'),
      'owner_balance_insufficient_for_reversal' =>
        const ConflictException(message: 'owner_balance_insufficient_for_reversal'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Dispute _disputeFromRow(Map<String, dynamic> row) {
    return Dispute(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      raisedBy: row['raised_by'] as String,
      category: DisputeCategory.fromId(row['category'] as String),
      description: row['description'] as String,
      evidencePaths: (row['evidence_paths'] as List<dynamic>? ?? const []).cast<String>(),
      status: DisputeStatus.fromId(row['status'] as String),
      resolutionNotes: row['resolution_notes'] as String?,
      resolvedBy: row['resolved_by'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  // -- Reports ------------------------------------------------------------

  @override
  Future<List<Report>> getOpenReports() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('reports')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);
      return rows.map(_reportFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Report> resolveReport({required String reportId, required ReportStatus newStatus}) async {
    try {
      final dynamic response = await _client.rpc<dynamic>('admin_resolve_report', params: {
        'p_report_id': reportId,
        'p_new_status': newStatus.id,
      });
      return _reportFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapReportError(e);
    }
  }

  AppException _mapReportError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'invalid_status' => const ValidationException(message: 'invalid_status'),
      'report_not_found' => const NotFoundException(message: 'not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Report _reportFromRow(Map<String, dynamic> row) {
    return Report(
      id: row['id'] as String,
      reporterId: row['reporter_id'] as String,
      targetType: ReportTargetType.fromId(row['target_type'] as String),
      targetId: row['target_id'] as String,
      reason: row['reason'] as String,
      details: row['details'] as String?,
      status: ReportStatus.fromId(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      resolvedAt: row['resolved_at'] != null ? DateTime.parse(row['resolved_at'] as String) : null,
    );
  }

  // -- Platform settings --------------------------------------------------

  @override
  Future<PlatformSettings> getPlatformSettings() async {
    try {
      final Map<String, dynamic> row =
          await _client.from('platform_settings').select().eq('id', 1).single();
      return _settingsFromRow(row);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<PlatformSettings> updateCommissionPercent(double percent) async {
    try {
      final dynamic response = await _client.rpc<dynamic>(
        'admin_update_commission_percent',
        params: {'p_percent': percent},
      );
      return _settingsFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapSettingsError(e);
    }
  }

  AppException _mapSettingsError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'invalid_commission_percent' => const ValidationException(message: 'invalid_commission_percent'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  PlatformSettings _settingsFromRow(Map<String, dynamic> row) {
    return PlatformSettings(
      commissionPercent: (row['commission_percent'] as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      updatedBy: row['updated_by'] as String?,
    );
  }

  // -- Promotions -----------------------------------------------------

  @override
  Future<List<Promotion>> getPromotions() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('promotions').select().order('created_at', ascending: false);
      return rows.map(_promotionFromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
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
    try {
      final dynamic response = await _client.rpc<dynamic>('admin_upsert_promotion', params: {
        'p_id': id,
        'p_code': code,
        'p_title': title,
        'p_description': description,
        'p_discount_percent': discountPercent,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_is_active': isActive,
      });
      return _promotionFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapPromotionError(e);
    }
  }

  @override
  Future<Promotion> deactivatePromotion(String id) async {
    try {
      final dynamic response =
          await _client.rpc<dynamic>('admin_deactivate_promotion', params: {'p_id': id});
      return _promotionFromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapPromotionError(e);
    }
  }

  AppException _mapPromotionError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'title_required' => const ValidationException(message: 'title_required'),
      'invalid_discount_percent' => const ValidationException(message: 'invalid_discount_percent'),
      'invalid_date_range' => const ValidationException(message: 'invalid_date_range'),
      'promotion_not_found' => const NotFoundException(message: 'not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }

  Promotion _promotionFromRow(Map<String, dynamic> row) {
    return Promotion(
      id: row['id'] as String,
      code: row['code'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      discountPercent: (row['discount_percent'] as num?)?.toDouble(),
      startsAt: DateTime.parse(row['starts_at'] as String),
      endsAt: DateTime.parse(row['ends_at'] as String),
      isActive: row['is_active'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<WireTopupReconciliationResult> reconcileWireTopups() async {
    try {
      final FunctionResponse response = await _client.functions.invoke('reconcile-wire-topups');
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      final List<dynamic> results = (data['results'] as List?) ?? const [];
      int credited = 0;
      int markedFailed = 0;
      for (final dynamic entry in results) {
        final String outcome = (entry as Map)['outcome'] as String? ?? '';
        if (outcome == 'credited') credited++;
        if (outcome == 'marked_failed' || outcome == 'not_found_marked_failed') markedFailed++;
      }
      return WireTopupReconciliationResult(
        checked: data['reconciled'] as int? ?? results.length,
        credited: credited,
        markedFailed: markedFailed,
      );
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  /// Same status-based mapping reasoning as
  /// `SupabaseWalletTopupRepository._mapFunctionError` — Edge Functions
  /// signal outcomes via HTTP status, not Postgres-style named
  /// exceptions.
  AppException _mapFunctionError(FunctionException e) {
    return switch (e.status) {
      401 => const UnauthorizedException(message: 'auth_required'),
      403 => const ForbiddenException(message: 'not_authorized'),
      _ => UnknownException(message: 'reconcile_wire_topups_function_error', cause: e),
    };
  }

  // -- App banners ------------------------------------------------------

  @override
  Future<List<AppBanner>> getAppBanners() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('app_banners').select().order('sort_order', ascending: true);
      return rows.map(AppBanner.fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<AppBanner> upsertAppBanner({
    String? id,
    required String storagePath,
    required int sortOrder,
    required bool isActive,
  }) async {
    try {
      final dynamic response = await _client.rpc<dynamic>('admin_upsert_app_banner', params: {
        'p_id': id,
        'p_storage_path': storagePath,
        'p_sort_order': sortOrder,
        'p_is_active': isActive,
      });
      return AppBanner.fromRow(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw _mapAppBannerError(e);
    }
  }

  @override
  Future<void> deleteAppBanner(String id) async {
    try {
      await _client.rpc<dynamic>('admin_delete_app_banner', params: {'p_id': id});
    } on PostgrestException catch (e) {
      throw _mapAppBannerError(e);
    }
  }

  AppException _mapAppBannerError(PostgrestException e) {
    return switch (e.message) {
      'not_authorized' => const ForbiddenException(message: 'not_authorized'),
      'image_required' => const ValidationException(message: 'image_required'),
      'banner_not_found' => const NotFoundException(message: 'not_found'),
      _ => UnknownException(message: e.message, cause: e),
    };
  }
}
