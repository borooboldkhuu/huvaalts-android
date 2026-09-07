import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/assets/domain/entities/asset_card.dart';
import 'package:huvalts/features/assets/domain/entities/asset_detail.dart';
import 'package:huvalts/features/assets/domain/entities/asset_search_filters.dart';
import 'package:huvalts/features/assets/domain/entities/new_asset_input.dart';
import 'package:huvalts/features/assets/domain/repositories/asset_repository.dart';
import 'package:huvalts/features/assets/presentation/controllers/asset_create_controller.dart';
import 'package:huvalts/features/assets/presentation/controllers/asset_providers.dart';

class _FakeAssetRepository implements AssetRepository {
  NewAssetInput? lastInput;
  List<PickedAssetImage>? lastImages;
  Object? errorToThrow;

  @override
  Future<String> createAsset(NewAssetInput input, List<PickedAssetImage> images) async {
    if (errorToThrow != null) throw errorToThrow!;
    lastInput = input;
    lastImages = images;
    return 'new-asset-id';
  }

  @override
  Future<AssetPage> search(AssetSearchFilters filters, {DateTime? cursor, int limit = 20}) async {
    return const AssetPage(items: [], nextCursor: null);
  }

  @override
  Future<AssetCard?> getById(String assetId) async => null;

  @override
  Future<AssetDetail?> getDetailById(String assetId) async => null;

  @override
  Future<List<AssetCard>> getMyAssets() async => const [];

  @override
  Future<void> incrementViewCount(String assetId) async {}
}

PickedAssetImage _image(int seed) {
  return PickedAssetImage(bytes: Uint8List.fromList([seed]), fileExtension: 'jpg');
}

void main() {
  group('AssetCreateController image list management', () {
    test('removeImageAt removes exactly the targeted image', () {
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(_FakeAssetRepository())],
      );
      addTearDown(container.dispose);

      final img0 = _image(0);
      final img1 = _image(1);
      final img2 = _image(2);
      final controller = container.read(assetCreateControllerProvider.notifier);
      controller.state = AssetCreateState(images: [img0, img1, img2]);

      controller.removeImageAt(1);

      expect(controller.state.images, [img0, img2]);
    });

    test('reorderImage moves an image from oldIndex to newIndex (ReorderableListView semantics)', () {
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(_FakeAssetRepository())],
      );
      addTearDown(container.dispose);

      final img0 = _image(0);
      final img1 = _image(1);
      final img2 = _image(2);
      final controller = container.read(assetCreateControllerProvider.notifier);
      controller.state = AssetCreateState(images: [img0, img1, img2]);

      // Moving index 0 to "new index 2" per ReorderableListView's
      // contract means "insert after removing the source item", so img0
      // should end up between img1 and img2 — i.e. the final order is
      // [img1, img0, img2], not [img1, img2, img0].
      controller.reorderImage(0, 2);

      expect(controller.state.images, [img1, img0, img2]);
    });

    test('reset clears images and submitting state', () {
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(_FakeAssetRepository())],
      );
      addTearDown(container.dispose);

      final controller = container.read(assetCreateControllerProvider.notifier);
      controller.state = AssetCreateState(images: [_image(0)]);

      controller.reset();

      expect(controller.state.images, isEmpty);
      expect(controller.state.isSubmitting, isFalse);
    });
  });

  group('AssetCreateController.submit', () {
    test('forwards the input and current images to the repository, returns the new id', () async {
      final fake = _FakeAssetRepository();
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final img = _image(0);
      final controller = container.read(assetCreateControllerProvider.notifier);
      controller.state = AssetCreateState(images: [img]);

      const input = NewAssetInput(
        title: 'Camera',
        description: '',
        categoryId: 'camera',
        pricePerDay: 40000,
      );

      final String id = await controller.submit(input);

      expect(id, 'new-asset-id');
      expect(fake.lastInput, input);
      expect(fake.lastImages, [img]);
      expect(controller.state.isSubmitting, isFalse, reason: 'must reset after completing');
    });

    test('rethrows on failure and still resets isSubmitting', () async {
      final fake = _FakeAssetRepository()..errorToThrow = Exception('boom');
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(assetCreateControllerProvider.notifier);
      const input = NewAssetInput(title: 'Camera', description: '', categoryId: 'camera', pricePerDay: 1);

      await expectLater(controller.submit(input), throwsException);
      expect(controller.state.isSubmitting, isFalse);
    });
  });
}
