import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Reads/writes the public `profiles` table (see
/// `supabase/migrations/0001_init_schema.sql`). RLS restricts writes to the
/// row's own owner — see `supabase/migrations/0002_rls_policies.sql`.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile> getProfile(String userId) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    }
  }

  @override
  Future<Profile> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('user_id', userId)
          .select()
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    }
  }

  Profile _fromRow(Map<String, dynamic> row) {
    return Profile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      verificationLevel: row['verification_level'] as int? ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: row['review_count'] as int? ?? 0,
      completedRentalsCount: row['completed_rentals_count'] as int? ?? 0,
      assetsCount: row['assets_count'] as int? ?? 0,
      memberSince: DateTime.parse(row['created_at'] as String),
    );
  }

  AppException _mapPostgrestException(PostgrestException e) {
    return switch (e.code) {
      'PGRST116' => const NotFoundException(message: 'profile_not_found'),
      '42501' => const ForbiddenException(),
      _ => UnknownException(message: e.message, cause: e),
    };
  }
}
