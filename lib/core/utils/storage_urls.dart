import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves a Supabase Storage object path (as stored in
/// `asset_images.storage_path` etc.) to a fetchable URL for the one
/// *public* bucket, `asset-images`. The two private buckets
/// (`condition-reports`, `dispute-evidence`, Phase 9) can't work this way
/// — a signed URL is scoped to whoever requested it and expires, so it
/// isn't a pure function of the path alone. Those go through their own
/// repository's `signedPhotoUrl`-style method instead (see
/// `ConditionReportRepository.signedPhotoUrl`) rather than living here.
class StorageUrls {
  const StorageUrls._();

  static const String assetImagesBucket = 'asset-images';

  /// Null-safe: returns null for a null/empty path so callers can do
  /// `StorageUrls.assetImage(card.primaryImagePath)` directly in a
  /// `NetworkImage`/`CachedNetworkImage` without a separate null check.
  static String? assetImage(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;
    return Supabase.instance.client.storage.from(assetImagesBucket).getPublicUrl(storagePath);
  }
}
