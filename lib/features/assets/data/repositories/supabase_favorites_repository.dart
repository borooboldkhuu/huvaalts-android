import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/favorites_repository.dart';

class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) throw const UnauthorizedException(message: 'not_signed_in');
    return id;
  }

  @override
  Future<bool> isFavorite(String assetId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('favorites')
          .select('asset_id')
          .eq('user_id', _userId)
          .eq('asset_id', assetId)
          .limit(1);
      return rows.isNotEmpty;
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> add(String assetId) async {
    try {
      await _client.from('favorites').upsert({
        'user_id': _userId,
        'asset_id': assetId,
      });
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> remove(String assetId) async {
    try {
      await _client.from('favorites').delete().eq('user_id', _userId).eq('asset_id', assetId);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<Set<String>> favoriteAssetIds() async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from('favorites').select('asset_id').eq('user_id', _userId);
      return rows.map((r) => r['asset_id'] as String).toSet();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }
}
