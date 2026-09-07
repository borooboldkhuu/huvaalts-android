import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/listing_suggestion.dart';
import 'listing_assistant_providers.dart';

class SuggestListingState {
  const SuggestListingState({this.isSubmitting = false});

  final bool isSubmitting;
}

/// Same success/in-flight/failure shape as every other action controller
/// in this app (`SendMessageController`, `SubmitReviewController`, ...) —
/// the create-listing screen owns what to *do* with a returned
/// [ListingSuggestion] (which fields to prefill), this controller just
/// owns the async call.
class SuggestListingController extends Notifier<SuggestListingState> {
  @override
  SuggestListingState build() => const SuggestListingState();

  Future<ListingSuggestion> suggest(List<(Uint8List bytes, String fileExtension)> photos) async {
    state = const SuggestListingState(isSubmitting: true);
    try {
      final ListingSuggestion suggestion =
          await ref.read(listingAssistantRepositoryProvider).suggestFromPhotos(photos);
      state = const SuggestListingState();
      return suggestion;
    } catch (_) {
      state = const SuggestListingState();
      rethrow;
    }
  }
}

final NotifierProvider<SuggestListingController, SuggestListingState>
    suggestListingControllerProvider =
    NotifierProvider<SuggestListingController, SuggestListingState>(SuggestListingController.new);
