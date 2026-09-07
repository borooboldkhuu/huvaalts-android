import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// The *public* view of a user — what any other user sees on a listing,
/// review, or chat (spec section 28). Never carries phone/email/national
/// ID; those stay on the private `AppUser`/backend-only records
/// (spec section 33).
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String userId,
    required String displayName,
    required String? avatarUrl,
    required int verificationLevel,
    required double rating,
    required int reviewCount,
    required int completedRentalsCount,
    required int assetsCount,
    required DateTime memberSince,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
}
