import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/identity_details_repository.dart';

class SupabaseIdentityDetailsRepository implements IdentityDetailsRepository {
  SupabaseIdentityDetailsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> exists(String userId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('identity_details')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> submit({
    required String userId,
    required String surname,
    required String givenName,
    required String registerNumber,
  }) async {
    try {
      // Upsert (not insert): safe to call again if a first attempt
      // succeeded on the server but the client never saw the response
      // (network blip) — a retry corrects/re-saves the same row instead
      // of failing on the primary key.
      await _client.from('identity_details').upsert({
        'user_id': userId,
        'surname': surname,
        'given_name': givenName,
        'register_number': registerNumber,
      });
    } on PostgrestException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(PostgrestException e) {
    if (e.code == '23505') {
      return const ConflictException(message: 'register_number_already_used');
    }
    if (e.code == '42501') return const ForbiddenException();
    return UnknownException(message: e.message, cause: e);
  }
}
