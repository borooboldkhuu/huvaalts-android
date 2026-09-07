import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/assets/domain/entities/asset_card.dart';
import 'package:huvalts/features/assets/domain/entities/asset_detail.dart';
import 'package:huvalts/features/assets/domain/entities/asset_search_filters.dart';
import 'package:huvalts/features/assets/domain/entities/new_asset_input.dart';
import 'package:huvalts/features/assets/domain/repositories/asset_repository.dart';
import 'package:huvalts/features/assets/presentation/controllers/asset_providers.dart';
import 'package:huvalts/features/search/presentation/controllers/search_controller.dart';

class _FakeAssetRepository implements AssetRepository {
  int callCount = 0;
  AssetSearchFilters? lastFilters;

  @override
  Future<AssetPage> search(AssetSearchFilters filters, {DateTime? cursor, int limit = 20}) async {
    callCount++;
    lastFilters = filters;
    return const AssetPage(items: [], nextCursor: null);
  }

  @override
  Future<AssetCard?> getById(String assetId) async => null;

  // Not exercised by these debounce/filter tests — this fake exists only
  // to satisfy AssetRepository's full interface (Dart requires every
  // abstract member implemented for a class using `implements`).
  @override
  Future<AssetDetail?> getDetailById(String assetId) async => null;

  @override
  Future<String> createAsset(NewAssetInput input, List<PickedAssetImage> images) async {
    throw UnimplementedError('not exercised by search_controller_test');
  }

  @override
  Future<List<AssetCard>> getMyAssets() async => const [];

  @override
  Future<void> incrementViewCount(String assetId) async {}
}

void main() {
  // Timer-based debounce only runs on a controllable clock inside
  // `testWidgets` (Flutter's test binding fakes async time for
  // `tester.pump`); a plain `test()` would run the real 400ms wall-clock
  // wait, which is slow and flaky to assert around.
  testWidgets('debounces rapid setQuery calls into a single search for the final value', (tester) async {
    final fake = _FakeAssetRepository();
    final container = ProviderContainer(
      overrides: [assetRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(searchControllerProvider.notifier);
    controller.initialize();
    await tester.pump();
    expect(fake.callCount, 1, reason: 'initialize() should search once immediately');

    controller.setQuery('a');
    controller.setQuery('ab');
    controller.setQuery('abc');

    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.callCount, 1, reason: 'debounce window has not elapsed yet');

    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.callCount, 2, reason: 'exactly one debounced search should have fired');
    expect(fake.lastFilters?.query, 'abc');
  });

  testWidgets('applyFilters searches immediately, without waiting for debounce', (tester) async {
    final fake = _FakeAssetRepository();
    final container = ProviderContainer(
      overrides: [assetRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final controller = container.read(searchControllerProvider.notifier);
    controller.initialize();
    await tester.pump();
    expect(fake.callCount, 1);

    controller.applyFilters(const AssetSearchFilters(verifiedOwnersOnly: true));
    await tester.pump();
    expect(fake.callCount, 2);
    expect(fake.lastFilters?.verifiedOwnersOnly, isTrue);
  });
}
