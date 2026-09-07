import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/ai/domain/entities/listing_suggestion.dart';
import 'package:huvalts/features/ai/domain/repositories/listing_assistant_repository.dart';
import 'package:huvalts/features/ai/presentation/controllers/listing_assistant_providers.dart';
import 'package:huvalts/features/ai/presentation/controllers/suggest_listing_controller.dart';

ListingSuggestion _suggestion() {
  return const ListingSuggestion(
    mock: true,
    titleSuggestion: null,
    descriptionSuggestion: 'Fill in details about this item...',
    conditionSuggestion: 'good',
    suggestedSpecFields: ['brand', 'model'],
  );
}

class _FakeListingAssistantRepository implements ListingAssistantRepository {
  int callCount = 0;
  List<(Uint8List, String)>? lastPhotos;
  Object? errorToThrow;

  @override
  Future<ListingSuggestion> suggestFromPhotos(List<(Uint8List, String)> photos) async {
    callCount++;
    lastPhotos = photos;
    if (errorToThrow != null) throw errorToThrow!;
    return _suggestion();
  }
}

void main() {
  test('suggest forwards the photos and returns the suggestion', () async {
    final fake = _FakeListingAssistantRepository();
    final container = ProviderContainer(
      overrides: [listingAssistantRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(suggestListingControllerProvider.notifier);
    final photos = [(Uint8List.fromList([1, 2, 3]), 'jpg')];
    final suggestion = await controller.suggest(photos);

    expect(suggestion.mock, isTrue);
    expect(suggestion.suggestedSpecFields, ['brand', 'model']);
    expect(fake.callCount, 1);
    expect(fake.lastPhotos, photos);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('isSubmitting is true only while the call is in flight', () async {
    final fake = _FakeListingAssistantRepository();
    final container = ProviderContainer(
      overrides: [listingAssistantRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(suggestListingControllerProvider.notifier);
    expect(controller.state.isSubmitting, isFalse);

    final future = controller.suggest([(Uint8List.fromList([1]), 'jpg')]);
    expect(controller.state.isSubmitting, isTrue);

    await future;
    expect(controller.state.isSubmitting, isFalse);
  });

  test('rethrows on failure (e.g. rate limited) and still resets isSubmitting', () async {
    final fake = _FakeListingAssistantRepository()..errorToThrow = Exception('rate_limited');
    final container = ProviderContainer(
      overrides: [listingAssistantRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(suggestListingControllerProvider.notifier);

    await expectLater(
      controller.suggest([(Uint8List.fromList([1]), 'jpg')]),
      throwsException,
    );
    expect(controller.state.isSubmitting, isFalse);
  });
}
