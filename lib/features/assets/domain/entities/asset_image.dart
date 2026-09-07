import 'package:freezed_annotation/freezed_annotation.dart';

part 'asset_image.freezed.dart';
part 'asset_image.g.dart';

/// One photo attached to a listing (a row in `asset_images`).
///
/// Name collision warning: Flutter's own `material.dart`/`painting.dart`
/// exports a class also called `AssetImage` (an `ImageProvider` for
/// bundled app assets — completely unrelated to this one). Any file that
/// imports both `package:flutter/material.dart` and this file must alias
/// one of the two imports (e.g. `import 'asset_image.dart' as entities;`)
/// or the analyzer will refuse to resolve the ambiguous name. See
/// `presentation/screens/asset_detail_screen.dart` for the pattern.
@freezed
abstract class AssetImage with _$AssetImage {
  const factory AssetImage({
    required String id,
    required String storagePath,
    required int sortOrder,
  }) = _AssetImage;

  factory AssetImage.fromJson(Map<String, dynamic> json) => _$AssetImageFromJson(json);
}
