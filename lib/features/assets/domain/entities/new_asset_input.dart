import 'dart:typed_data';

/// Everything the create-listing form (spec section 14) collects before
/// submit. Plain (not freezed) — this is a one-shot transfer object built
/// once at submit time, not app state that needs `copyWith`/equality.
class NewAssetInput {
  const NewAssetInput({
    required this.title,
    required this.description,
    required this.categoryId,
    this.brand,
    this.model,
    this.condition,
    this.specifications = const {},
    this.pricePerHour,
    this.pricePerDay,
    this.pricePerWeek,
    this.pickupMethod,
    this.deliveryAvailable = false,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.rules = const [],
  });

  final String title;
  final String description;
  final String categoryId;
  final String? brand;
  final String? model;
  final String? condition;
  final Map<String, String> specifications;
  final double? pricePerHour;
  final double? pricePerDay;
  final double? pricePerWeek;
  final String? pickupMethod;
  final bool deliveryAvailable;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final List<String> rules;

  bool get hasAtLeastOnePrice => pricePerHour != null || pricePerDay != null || pricePerWeek != null;
}

/// A picked/compressed image ready to upload — deliberately not an
/// `image_picker` `XFile` so the domain layer (and this class's only
/// consumer, `AssetRepository.createAsset`) never depends on a Flutter
/// plugin type. The presentation layer converts `XFile` -> this.
class PickedAssetImage {
  const PickedAssetImage({required this.bytes, required this.fileExtension});

  final Uint8List bytes;

  /// Without the leading dot, e.g. `jpg`.
  final String fileExtension;
}
