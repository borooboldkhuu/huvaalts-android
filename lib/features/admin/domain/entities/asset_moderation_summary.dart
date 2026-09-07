import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../assets/domain/entities/asset_status.dart';

part 'asset_moderation_summary.freezed.dart';

/// Read-optimized projection for the admin moderation queue, sourced from
/// the same `public.asset_cards` view as `AssetCard` (spec section 29,
/// `supabase/migrations/0012_admin_dashboard.sql` extends the 0004 view
/// with `moderation_note`) but scoped to `status`es an admin actually
/// needs to act on (`pendingReview`, `published`), never the full public
/// browse feed.
///
/// `AssetCard` itself also carries `status`/`moderationNote` now (so
/// `MyAssetsScreen` can show an owner why their own listing isn't public
/// yet) — this stays a separate entity anyway rather than reusing
/// `AssetCard` here too, because the two queries have genuinely different
/// shapes: this one is unfiltered-by-owner (`getPendingAssets` — any
/// pending/published asset, any owner) while `AssetCard` rows are always
/// either the public `published` feed or one owner's own assets. Sharing
/// one entity would work today but would make it easy to accidentally
/// wire an admin-only query result into a public-facing widget later.
@freezed
abstract class AssetModerationSummary with _$AssetModerationSummary {
  const factory AssetModerationSummary({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
    required String title,
    required AssetStatus status,
    required String? moderationNote,
    required String? primaryImagePath,
    required double? displayPrice,
    required String currency,
    required DateTime createdAt,
  }) = _AssetModerationSummary;
}
