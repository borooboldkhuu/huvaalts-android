import 'dart:typed_data';

import '../entities/listing_suggestion.dart';

abstract interface class ListingAssistantRepository {
  /// Sends up to a few already-picked photos to `suggest-listing-from-photo`
  /// and returns a suggestion to prefill the create-listing form with.
  /// Throws [RateLimitedException] (via the mapped [AppException]) once
  /// the caller's daily call count is exhausted — see that function's
  /// `MAX_CALLS_PER_DAY`.
  Future<ListingSuggestion> suggestFromPhotos(
    List<(Uint8List bytes, String fileExtension)> photos,
  );
}
