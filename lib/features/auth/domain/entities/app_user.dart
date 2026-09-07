import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// The authenticated user's own view of themselves. Deliberately excludes
/// anything another user shouldn't see — for the public-facing profile a
/// user sees of *someone else*, see `features/profile/domain/entities/profile.dart`.
///
/// Never includes: national ID number, raw DAN payload, payment secrets
/// (spec sections 10, 33).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String? phone,
    required String? email,
    required String? displayName,
    required String? avatarUrl,
    required int verificationLevel,
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}
