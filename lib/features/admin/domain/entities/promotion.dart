import 'package:freezed_annotation/freezed_annotation.dart';

part 'promotion.freezed.dart';
part 'promotion.g.dart';

/// A `public.promotions` row (spec section 30) — existed since Phase 0's
/// schema, but nothing in this app ever read or wrote one until Phase 12,
/// which closes the admin-authoring side (`admin_upsert_promotion`/
/// `admin_deactivate_promotion`,
/// `supabase/migrations/0013_security_perf_hardening.sql`). There is
/// still no consumer-facing "apply this promo code at booking" flow —
/// that's a separate, real, un-started feature, not something this phase
/// claims to cover.
@freezed
abstract class Promotion with _$Promotion {
  const factory Promotion({
    required String id,
    required String? code,
    required String title,
    required String? description,
    required double? discountPercent,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
    required DateTime createdAt,
  }) = _Promotion;

  factory Promotion.fromJson(Map<String, dynamic> json) => _$PromotionFromJson(json);
}
