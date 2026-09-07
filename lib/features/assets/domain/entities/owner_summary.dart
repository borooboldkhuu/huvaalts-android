import 'package:freezed_annotation/freezed_annotation.dart';

part 'owner_summary.freezed.dart';
part 'owner_summary.g.dart';

/// The owner-facing slice of a `profiles` row shown on asset detail (spec
/// section 16: "Owner", "Verification"). Deliberately narrower than
/// `features/profile`'s `Profile` entity — asset detail only ever needs
/// this much, not the full profile stats block.
@freezed
abstract class OwnerSummary with _$OwnerSummary {
  const factory OwnerSummary({
    required String userId,
    required String displayName,
    required String? avatarUrl,
    required int verificationLevel,
    required double rating,
    required int reviewCount,
    required DateTime memberSince,
  }) = _OwnerSummary;

  factory OwnerSummary.fromJson(Map<String, dynamic> json) => _$OwnerSummaryFromJson(json);
}
