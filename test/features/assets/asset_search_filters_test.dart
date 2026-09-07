import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/assets/domain/entities/asset_search_filters.dart';

void main() {
  group('AssetSearchFilters.copyWith', () {
    test('clearQuery/clearCategory/clearMinPrice/clearMaxPrice actually clear, not no-op', () {
      const original = AssetSearchFilters(
        query: 'camera',
        categoryId: 'camera',
        minPrice: 10000,
        maxPrice: 90000,
      );

      final cleared = original.copyWith(
        clearQuery: true,
        clearCategory: true,
        clearMinPrice: true,
        clearMaxPrice: true,
      );

      expect(cleared.query, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared.minPrice, isNull);
      expect(cleared.maxPrice, isNull);
    });

    test('passing a new value overrides without needing the clear flag', () {
      const original = AssetSearchFilters(categoryId: 'camera');
      final updated = original.copyWith(categoryId: 'drone');
      expect(updated.categoryId, 'drone');
    });

    test('omitted fields are preserved across copyWith', () {
      const original = AssetSearchFilters(query: 'gopro', verifiedOwnersOnly: true);
      final updated = original.copyWith(sort: AssetSortOption.cheapest);
      expect(updated.query, 'gopro');
      expect(updated.verifiedOwnersOnly, isTrue);
      expect(updated.sort, AssetSortOption.cheapest);
    });

    test('isEmpty reflects whether any filter dimension is set', () {
      expect(const AssetSearchFilters().isEmpty, isTrue);
      expect(const AssetSearchFilters(query: 'x').isEmpty, isFalse);
      expect(const AssetSearchFilters(verifiedOwnersOnly: true).isEmpty, isFalse);
    });

    test('hasLocation requires both latitude and longitude', () {
      expect(const AssetSearchFilters().hasLocation, isFalse);
      expect(const AssetSearchFilters(nearLatitude: 47.9).hasLocation, isFalse);
      expect(
        const AssetSearchFilters(nearLatitude: 47.9, nearLongitude: 106.9).hasLocation,
        isTrue,
      );
    });
  });
}
