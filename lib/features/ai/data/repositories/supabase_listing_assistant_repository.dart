import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/listing_suggestion.dart';
import '../../domain/repositories/listing_assistant_repository.dart';

class SupabaseListingAssistantRepository implements ListingAssistantRepository {
  SupabaseListingAssistantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ListingSuggestion> suggestFromPhotos(
    List<(Uint8List bytes, String fileExtension)> photos,
  ) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'suggest-listing-from-photo',
        body: {
          'photos': [for (final (bytes, _) in photos) base64Encode(bytes)],
        },
      );
      final Map<String, dynamic> data = (response.data as Map).cast<String, dynamic>();
      return ListingSuggestion(
        mock: data['mock'] as bool? ?? true,
        titleSuggestion: data['title_suggestion'] as String?,
        descriptionSuggestion: data['description_suggestion'] as String? ?? '',
        conditionSuggestion: data['condition_suggestion'] as String? ?? 'good',
        suggestedSpecFields:
            (data['suggested_spec_fields'] as List<dynamic>? ?? const []).cast<String>(),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    }
  }

  /// Same status-code-based mapping `EdgeFunctionDanAuthAdapter` uses —
  /// this function doesn't raise Postgres-style named exceptions either,
  /// so the HTTP status it chose is the only reliable signal.
  AppException _mapFunctionError(FunctionException e) {
    return switch (e.status) {
      401 => const UnauthorizedException(message: 'auth_required'),
      400 => const ValidationException(message: 'at_least_one_photo_required'),
      429 => const RateLimitedException(message: 'rate_limited'),
      501 => const ValidationException(message: 'ai_listing_production_adapter_not_implemented'),
      _ => UnknownException(message: 'ai_listing_function_error', cause: e),
    };
  }
}
