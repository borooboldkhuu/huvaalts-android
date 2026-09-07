import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../domain/entities/asset_card.dart';
import '../../domain/entities/asset_detail.dart';
import '../../domain/entities/asset_image.dart';
import '../../domain/entities/asset_search_filters.dart';
import '../../domain/entities/asset_status.dart';
import '../../domain/entities/new_asset_input.dart';
import '../../domain/entities/owner_summary.dart';
import '../../domain/repositories/asset_repository.dart';

/// Queries the `public.asset_cards` view (see
/// `supabase/migrations/0004_asset_cards_view.sql`) rather than
/// `public.assets` directly, so a card's owner name/verification/rating/
/// primary image come back in one round trip.
///
/// Pagination note: true keyset pagination (cursor = last `created_at`)
/// only applies cleanly to the `recommended`/`newest` sorts, which are
/// both ultimately ordered by `created_at`. For `cheapest`/`mostExpensive`/
/// `highestRated`/`closest`, this implementation fetches a single page and
/// reports `nextCursor: null` — proper composite-key pagination for every
/// sort dimension is a reasonable follow-up once these screens have real
/// usage data to justify it, not something to guess at now.
class SupabaseAssetRepository implements AssetRepository {
  SupabaseAssetRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'asset_cards';

  @override
  Future<AssetPage> search(
    AssetSearchFilters filters, {
    DateTime? cursor,
    int limit = 20,
  }) async {
    try {
      // "closest" needs client-side distance sorting (no PostGIS in this
      // schema yet) — fetch a wider recent batch, sort by Haversine
      // distance, then trim to `limit`.
      final bool isClosestSort =
          filters.sort == AssetSortOption.closest && filters.hasLocation;
      final int fetchLimit = isClosestSort ? limit * 4 : limit;

      PostgrestFilterBuilder<PostgrestList> query =
          _client.from(_table).select().eq('status', 'published');

      if (filters.query != null && filters.query!.trim().isNotEmpty) {
        // As of Phase 12, real full-text search against `search_vector`
        // (a generated `tsvector` over title/description/brand/model —
        // `0013_security_perf_hardening.sql`) rather than a `title`-only
        // `ILIKE '%query%'`, which no index can make fast on a leading
        // wildcard. `TextSearchType.websearch` accepts a plain free-text
        // query the way a user actually types one (quotes, `-exclude`,
        // `or`) instead of requiring hand-built `to_tsquery` operator
        // syntax. `config: 'simple'` matches the column's own generation
        // expression — see that migration's header comment for why
        // 'simple' (tokenize + lowercase, no linguistic stemming) rather
        // than 'english', since Postgres ships no Mongolian dictionary.
        query = query.textSearch(
          'search_vector',
          filters.query!.trim(),
          config: 'simple',
          type: TextSearchType.websearch,
        );
      }
      if (filters.categoryId != null && filters.categoryId != 'all') {
        query = query.eq('category_id', filters.categoryId!);
      }
      if (filters.minPrice != null) {
        query = query.gte('display_price', filters.minPrice!);
      }
      if (filters.maxPrice != null) {
        query = query.lte('display_price', filters.maxPrice!);
      }
      if (filters.verifiedOwnersOnly) {
        query = query.gte('owner_verification_level', 1);
      }
      if (filters.featuredOnly) {
        query = query.eq('is_featured', true);
      }
      if (filters.minRating != null) {
        query = query.gte('asset_rating', filters.minRating!);
      }

      // Cursor pagination only applies to created_at-ordered sorts.
      final bool cursorApplies =
          filters.sort == AssetSortOption.recommended || filters.sort == AssetSortOption.newest;
      if (cursorApplies && cursor != null) {
        query = query.lt('created_at', cursor.toIso8601String());
      }

      final PostgrestTransformBuilder<PostgrestList> ordered = switch (filters.sort) {
        AssetSortOption.recommended =>
          query.order('is_featured', ascending: false).order('created_at', ascending: false),
        AssetSortOption.cheapest => query.order('display_price', ascending: true),
        AssetSortOption.mostExpensive => query.order('display_price', ascending: false),
        AssetSortOption.highestRated => query.order('asset_rating', ascending: false),
        AssetSortOption.newest => query.order('created_at', ascending: false),
        AssetSortOption.closest => query.order('created_at', ascending: false),
        AssetSortOption.mostViewed => query.order('view_count', ascending: false),
        AssetSortOption.mostFavorited => query.order('favorite_count', ascending: false),
      };

      final List<Map<String, dynamic>> rows = await ordered.limit(fetchLimit);
      List<AssetCard> items = rows.map(_fromRow).toList();

      if (isClosestSort) {
        final double lat = filters.nearLatitude!;
        final double lng = filters.nearLongitude!;
        items = items.where((a) => a.latitude != null && a.longitude != null).toList()
          ..sort((a, b) {
            final double da = GeoUtils.distanceKm(lat, lng, a.latitude!, a.longitude!);
            final double db = GeoUtils.distanceKm(lat, lng, b.latitude!, b.longitude!);
            return da.compareTo(db);
          });
        if (filters.radiusKm != null) {
          items = items
              .where((a) => GeoUtils.distanceKm(lat, lng, a.latitude!, a.longitude!) <= filters.radiusKm!)
              .toList();
        }
        items = items.take(limit).toList();
      }

      final DateTime? nextCursor = cursorApplies && items.length == fetchLimit && items.isNotEmpty
          ? items.last.createdAt
          : null;

      return AssetPage(items: items, nextCursor: nextCursor);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<AssetCard?> getById(String assetId) async {
    try {
      final List<Map<String, dynamic>> rows =
          await _client.from(_table).select().eq('id', assetId).limit(1);
      if (rows.isEmpty) return null;
      return _fromRow(rows.first);
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<AssetDetail?> getDetailById(String assetId) async {
    try {
      // Embedded select: asset_images/asset_rules have a direct FK to
      // assets, so PostgREST can nest them in one query. The owner's
      // profile and the aggregate rating can't be embedded the same way
      // (assets->profiles isn't a direct FK — both reference `users`; see
      // `0004_asset_cards_view.sql`'s comment) so those are two more
      // small queries rather than one big join.
      final Map<String, dynamic>? assetRow = await _client
          .from('assets')
          .select('*, asset_images(*), asset_rules(*)')
          .eq('id', assetId)
          .maybeSingle();
      if (assetRow == null) return null;

      final String ownerId = assetRow['owner_id'] as String;

      final Map<String, dynamic>? ownerRow =
          await _client.from('profiles').select().eq('user_id', ownerId).maybeSingle();

      final Map<String, dynamic>? cardRow = await _client
          .from(_table)
          .select('asset_rating, asset_review_count')
          .eq('id', assetId)
          .maybeSingle();

      final List<Map<String, dynamic>> imageMaps =
          ((assetRow['asset_images'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
      final List<AssetImage> images = imageMaps
          .map(
            (r) => AssetImage(
              id: r['id'] as String,
              storagePath: r['storage_path'] as String,
              sortOrder: r['sort_order'] as int? ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<Map<String, dynamic>> ruleMaps =
          ((assetRow['asset_rules'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>()
            ..sort(
              (a, b) => (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0),
            );
      final List<String> rules = ruleMaps.map((r) => r['rule'] as String).toList();

      final OwnerSummary owner = OwnerSummary(
        userId: ownerId,
        displayName: ownerRow?['display_name'] as String? ?? '',
        avatarUrl: ownerRow?['avatar_url'] as String?,
        verificationLevel: ownerRow?['verification_level'] as int? ?? 0,
        rating: (ownerRow?['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: ownerRow?['review_count'] as int? ?? 0,
        memberSince: DateTime.parse(
          (ownerRow?['created_at'] as String?) ?? assetRow['created_at'] as String,
        ),
      );

      return AssetDetail(
        id: assetRow['id'] as String,
        categoryId: assetRow['category_id'] as String,
        title: assetRow['title'] as String,
        description: assetRow['description'] as String? ?? '',
        brand: assetRow['brand'] as String?,
        model: assetRow['model'] as String?,
        condition: assetRow['condition'] as String?,
        specifications: ((assetRow['specifications'] as Map?)?.cast<String, dynamic>()) ?? const {},
        pricePerHour: (assetRow['price_per_hour'] as num?)?.toDouble(),
        pricePerDay: (assetRow['price_per_day'] as num?)?.toDouble(),
        pricePerWeek: (assetRow['price_per_week'] as num?)?.toDouble(),
        currency: assetRow['currency'] as String? ?? 'MNT',
        pickupMethod: assetRow['pickup_method'] as String?,
        deliveryAvailable: assetRow['delivery_available'] as bool? ?? false,
        latitude: (assetRow['latitude'] as num?)?.toDouble(),
        longitude: (assetRow['longitude'] as num?)?.toDouble(),
        locationLabel: assetRow['location_label'] as String?,
        status: assetRow['status'] as String,
        createdAt: DateTime.parse(assetRow['created_at'] as String),
        images: images,
        rules: rules,
        owner: owner,
        assetRating: (cardRow?['asset_rating'] as num?)?.toDouble() ?? 0,
        assetReviewCount: cardRow?['asset_review_count'] as int? ?? 0,
      );
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<String> createAsset(NewAssetInput input, List<PickedAssetImage> images) async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) throw const UnauthorizedException(message: 'not_signed_in');
    if (!input.hasAtLeastOnePrice) {
      throw const ValidationException(message: 'asset_needs_at_least_one_price');
    }

    try {
      // Step 1: the asset row. The `status: 'published'` sent here is
      // deliberately harmless, not honest client optimism — as of Phase
      // 11's `enforce_asset_status_transition` trigger
      // (`0012_admin_dashboard.sql`), every INSERT is forced server-side
      // to land in `pending_review` regardless of what the client sends,
      // closing the gap this comment used to document (new listings
      // published immediately with no moderation queue to catch them).
      // Left as `'published'` rather than rewritten to `'pending_review'`
      // only so a reader diffing this file can see the client's intent
      // never actually changed — the server just stopped trusting it.
      final Map<String, dynamic> assetRow = await _client
          .from('assets')
          .insert({
            'owner_id': userId,
            'category_id': input.categoryId,
            'title': input.title,
            'description': input.description,
            'brand': input.brand,
            'model': input.model,
            'condition': input.condition,
            'specifications': input.specifications,
            'price_per_hour': input.pricePerHour,
            'price_per_day': input.pricePerDay,
            'price_per_week': input.pricePerWeek,
            'pickup_method': input.pickupMethod,
            'delivery_available': input.deliveryAvailable,
            'latitude': input.latitude,
            'longitude': input.longitude,
            'location_label': input.locationLabel,
            'status': 'published',
          })
          .select()
          .single();

      final String assetId = assetRow['id'] as String;

      // Step 2: images, one at a time. Not wrapped in a single
      // all-or-nothing transaction — the Flutter client has no portable
      // way to run a multi-table Postgres transaction against Supabase,
      // and a Postgres function (RPC) that also handles Storage uploads
      // isn't practical since Storage writes aren't transactional with
      // the database anyway. So: the asset itself is created first (it's
      // useful on its own even with zero photos), and each image upload
      // is independent — one failing doesn't roll back the others or the
      // asset. An owner can always add more photos later once an edit
      // flow exists (not built this phase).
      const uuid = Uuid();
      int sortOrder = 0;
      for (final PickedAssetImage image in images) {
        final String path = '$assetId/${uuid.v4()}.${image.fileExtension}';
        try {
          await _client.storage
              .from(StorageUrls.assetImagesBucket)
              .uploadBinary(path, image.bytes, fileOptions: const FileOptions(upsert: false));
          await _client.from('asset_images').insert({
            'asset_id': assetId,
            'storage_path': path,
            'sort_order': sortOrder,
          });
          sortOrder++;
        } catch (_) {
          continue;
        }
      }

      // Step 3: rules.
      if (input.rules.isNotEmpty) {
        await _client.from('asset_rules').insert([
          for (int i = 0; i < input.rules.length; i++)
            {'asset_id': assetId, 'rule': input.rules[i], 'sort_order': i},
        ]);
      }

      return assetId;
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    } on StorageException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<List<AssetCard>> getMyAssets() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) throw const UnauthorizedException(message: 'not_signed_in');
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from(_table)
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      return rows.map(_fromRow).toList();
    } on PostgrestException catch (e) {
      throw UnknownException(message: e.message, cause: e);
    }
  }

  @override
  Future<void> incrementViewCount(String assetId) async {
    // Best-effort per the interface doc — swallow rather than throw, a
    // view-count bump should never surface an error over the asset detail
    // screen the user is actually trying to look at.
    try {
      await _client.rpc<void>('increment_asset_view_count', params: {'p_asset_id': assetId});
    } catch (_) {
      // Ignored — see above.
    }
  }

  AssetCard _fromRow(Map<String, dynamic> row) {
    return AssetCard(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      categoryId: row['category_id'] as String,
      title: row['title'] as String,
      status: AssetStatus.fromId(row['status'] as String? ?? 'published'),
      moderationNote: row['moderation_note'] as String?,
      pricePerHour: (row['price_per_hour'] as num?)?.toDouble(),
      pricePerDay: (row['price_per_day'] as num?)?.toDouble(),
      pricePerWeek: (row['price_per_week'] as num?)?.toDouble(),
      displayPrice: (row['display_price'] as num?)?.toDouble(),
      currency: row['currency'] as String? ?? 'MNT',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      locationLabel: row['location_label'] as String?,
      isFeatured: row['is_featured'] as bool? ?? false,
      viewCount: row['view_count'] as int? ?? 0,
      favoriteCount: row['favorite_count'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      ownerDisplayName: row['owner_display_name'] as String? ?? '',
      ownerVerificationLevel: row['owner_verification_level'] as int? ?? 0,
      primaryImagePath: row['primary_image_path'] as String?,
      assetRating: (row['asset_rating'] as num?)?.toDouble() ?? 0,
      assetReviewCount: row['asset_review_count'] as int? ?? 0,
    );
  }
}
