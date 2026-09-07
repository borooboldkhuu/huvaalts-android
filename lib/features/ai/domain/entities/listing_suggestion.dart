import 'package:freezed_annotation/freezed_annotation.dart';

part 'listing_suggestion.freezed.dart';
part 'listing_suggestion.g.dart';

/// The response shape of the `suggest-listing-from-photo` Edge Function
/// (Phase 10, spec sections 14, 51). `mock` is always `true` today — no
/// vision-capable API key was available, so [descriptionSuggestion] is a
/// fill-in-the-blanks template and [suggestedSpecFields] are field
/// *names* worth filling in, never fabricated values; [titleSuggestion]
/// is deliberately always null in mock mode rather than guessing. See
/// that function's own header comment for the production swap path —
/// this shape is designed to stay the same either way.
@freezed
abstract class ListingSuggestion with _$ListingSuggestion {
  const factory ListingSuggestion({
    required bool mock,
    required String? titleSuggestion,
    required String descriptionSuggestion,
    required String conditionSuggestion,
    required List<String> suggestedSpecFields,
  }) = _ListingSuggestion;

  factory ListingSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ListingSuggestionFromJson(json);
}
