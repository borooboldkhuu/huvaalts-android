import 'package:supabase_flutter/supabase_flutter.dart';

/// A `public.app_banners` row (`supabase/migrations/0023_app_banners.sql`)
/// — an image an admin uploaded to show in the rotating popup on Home's
/// first frame after app open (see `app_banner_popup.dart`). Plain class,
/// deliberately not `@freezed` like `Promotion` — this project's own
/// established pattern (`NewAssetInput`/`PickedAssetImage`) is to keep
/// one-shot/simple data classes hand-written where there's no Flutter SDK
/// in this sandbox to run `build_runner` and verify the generated
/// `.freezed.dart`/`.g.dart` output.
///
/// Lives under `shared/` rather than the admin feature's own
/// `domain/entities/` (where `Promotion` lives) because, unlike a
/// promotion, a banner is genuinely read by a non-admin surface (Home) —
/// putting it here avoids the home feature importing from the admin
/// feature just for a data type.
class AppBanner {
  const AppBanner({
    required this.id,
    required this.storagePath,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String storagePath;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  static const String storageBucket = 'app-banners';

  /// Resolves [storagePath] to a fetchable URL — `app-banners` is a
  /// public-read bucket (0023), same reasoning as `StorageUrls.assetImage`
  /// for `asset-images`.
  String get imageUrl => Supabase.instance.client.storage.from(storageBucket).getPublicUrl(storagePath);

  factory AppBanner.fromRow(Map<String, dynamic> row) {
    return AppBanner(
      id: row['id'] as String,
      storagePath: row['storage_path'] as String,
      sortOrder: row['sort_order'] as int,
      isActive: row['is_active'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
