import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset_status.dart';

part 'asset_card.freezed.dart';
part 'asset_card.g.dart';

/// Read-optimized projection backing browse/search cards (Home sections,
/// Search results — spec sections 11/12), sourced from the
/// `public.asset_cards` view (see
/// `supabase/migrations/0004_asset_cards_view.sql`,
/// `0012_admin_dashboard.sql` for the `status`/`moderationNote` addition).
/// This is deliberately *not* the full asset detail model — that's a
/// Phase 3 concern once the asset detail screen (description, full
/// gallery, rules, availability calendar) is built.
///
/// [status]/[moderationNote] are carried here (not only on the admin
/// feature's `AssetModerationSummary`) because every public browse/search
/// query already filters `.eq('status', 'published')` — those two fields
/// only ever hold real values for `MyAssetsScreen`'s query, which doesn't
/// filter by status, so an owner can see why their own pending/suspended
/// listing isn't publicly visible yet.
@freezed
abstract class AssetCard with _$AssetCard {
  const factory AssetCard({
    required String id,
    required String ownerId,
    required String categoryId,
    required String title,
    required AssetStatus status,
    required String? moderationNote,
    required double? pricePerHour,
    required double? pricePerDay,
    required double? pricePerWeek,
    // Server-computed single comparable price (per-day, else per-hour, else
    // per-week) — see `asset_cards` view. Used for sort/filter; card UI
    // should still prefer showing `pricePerDay` with its "/ өдөр" unit when
    // present.
    required double? displayPrice,
    required String currency,
    required double? latitude,
    required double? longitude,
    required String? locationLabel,
    required bool isFeatured,
    required int viewCount,
    required int favoriteCount,
    required DateTime createdAt,
    required String ownerDisplayName,
    required int ownerVerificationLevel,
    required String? primaryImagePath,
    required double assetRating,
    required int assetReviewCount,
  }) = _AssetCard;

  factory AssetCard.fromJson(Map<String, dynamic> json) => _$AssetCardFromJson(json);
}
