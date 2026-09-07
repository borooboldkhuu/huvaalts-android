import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset_image.dart';
import 'owner_summary.dart';

part 'asset_detail.freezed.dart';

/// Full asset detail (spec section 16) — gallery, specs, rules, owner,
/// rating. Distinct from [AssetCard]/`domain/entities/asset_card.dart`,
/// which is the lighter browse/search projection; this is what the detail
/// screen alone needs, fetched only when a user actually opens an asset.
///
/// No `fromJson` here (unlike the other entities) because this is
/// assembled from three separate queries in
/// `SupabaseAssetRepository.getDetailById` (assets+images+rules in one
/// embedded query, owner profile, and aggregate rating from
/// `asset_cards`) rather than mapped 1:1 from a single row.
@freezed
abstract class AssetDetail with _$AssetDetail {
  const factory AssetDetail({
    required String id,
    required String categoryId,
    required String title,
    required String description,
    required String? brand,
    required String? model,
    required String? condition,
    required Map<String, dynamic> specifications,
    required double? pricePerHour,
    required double? pricePerDay,
    required double? pricePerWeek,
    required String currency,
    required String? pickupMethod,
    required bool deliveryAvailable,
    required double? latitude,
    required double? longitude,
    required String? locationLabel,
    required String status,
    required DateTime createdAt,
    required List<AssetImage> images,
    required List<String> rules,
    required OwnerSummary owner,
    required double assetRating,
    required int assetReviewCount,
  }) = _AssetDetail;
}
