import 'package:flutter_test/flutter_test.dart';
import 'package:huvalts/features/assets/domain/entities/new_asset_input.dart';

void main() {
  group('NewAssetInput.hasAtLeastOnePrice', () {
    test('false when every price field is null', () {
      const input = NewAssetInput(title: 'Camera', description: '', categoryId: 'camera');
      expect(input.hasAtLeastOnePrice, isFalse);
    });

    test('true when only pricePerHour is set', () {
      const input = NewAssetInput(
        title: 'Camera',
        description: '',
        categoryId: 'camera',
        pricePerHour: 5000,
      );
      expect(input.hasAtLeastOnePrice, isTrue);
    });

    test('true when only pricePerDay is set', () {
      const input = NewAssetInput(
        title: 'Camera',
        description: '',
        categoryId: 'camera',
        pricePerDay: 40000,
      );
      expect(input.hasAtLeastOnePrice, isTrue);
    });

    test('true when only pricePerWeek is set', () {
      const input = NewAssetInput(
        title: 'Camera',
        description: '',
        categoryId: 'camera',
        pricePerWeek: 200000,
      );
      expect(input.hasAtLeastOnePrice, isTrue);
    });

    test('true when multiple price fields are set', () {
      const input = NewAssetInput(
        title: 'Camera',
        description: '',
        categoryId: 'camera',
        pricePerHour: 5000,
        pricePerDay: 40000,
      );
      expect(input.hasAtLeastOnePrice, isTrue);
    });
  });

  test('defaults: delivery is false, specs/rules are empty', () {
    const input = NewAssetInput(title: 'Camera', description: '', categoryId: 'camera');
    expect(input.deliveryAvailable, isFalse);
    expect(input.specifications, isEmpty);
    expect(input.rules, isEmpty);
  });
}
