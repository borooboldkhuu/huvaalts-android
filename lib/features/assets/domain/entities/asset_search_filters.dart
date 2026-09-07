/// How search/browse results should be ordered (spec section 12).
/// `closest` and a true "nearby" radius filter require a device location —
/// see [AssetSearchFilters.nearLatitude]/[nearLongitude]; when neither is
/// set, `closest` degrades to `newest` rather than throwing.
enum AssetSortOption {
  recommended,
  cheapest,
  mostExpensive,
  closest,
  highestRated,
  newest,

  /// Backs Home's "Popular" section — not user-facing in the Search sort
  /// picker (spec section 12 doesn't list it as a sort option there).
  mostViewed,

  /// Backs Home's "Trending" section — same note as [mostViewed].
  mostFavorited,
}

/// Every filter/sort dimension from spec section 12, plus the plumbing
/// ([nearLatitude]/[nearLongitude]/[radiusKm]) that Home's "Nearby" section
/// and a future Map view (spec section 13 — not built this phase) both
/// need. Immutable; build a new instance with [copyWith] rather than
/// mutating filters in place, so widgets can diff cheaply.
class AssetSearchFilters {
  const AssetSearchFilters({
    this.query,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.verifiedOwnersOnly = false,
    this.featuredOnly = false,
    this.minRating,
    this.sort = AssetSortOption.recommended,
    this.nearLatitude,
    this.nearLongitude,
    this.radiusKm,
  });

  final String? query;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final bool verifiedOwnersOnly;

  /// Restricts results to `is_featured = true` (the same column
  /// `recommended` sort already orders by — see the repository). Added for
  /// Home's featured/hero carousel, which needs an actual filter rather
  /// than just a sort tiebreaker: without this, a catalog with only a
  /// couple of featured listings would still show every other asset after
  /// them instead of stopping at the featured set.
  final bool featuredOnly;
  final double? minRating;
  final AssetSortOption sort;

  /// Device/browse-origin coordinates for distance sort/radius filtering.
  final double? nearLatitude;
  final double? nearLongitude;
  final double? radiusKm;

  bool get hasLocation => nearLatitude != null && nearLongitude != null;

  AssetSearchFilters copyWith({
    String? query,
    bool clearQuery = false,
    String? categoryId,
    bool clearCategory = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    bool? verifiedOwnersOnly,
    bool? featuredOnly,
    double? minRating,
    AssetSortOption? sort,
    double? nearLatitude,
    double? nearLongitude,
    double? radiusKm,
  }) {
    return AssetSearchFilters(
      query: clearQuery ? null : (query ?? this.query),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      verifiedOwnersOnly: verifiedOwnersOnly ?? this.verifiedOwnersOnly,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
      nearLatitude: nearLatitude ?? this.nearLatitude,
      nearLongitude: nearLongitude ?? this.nearLongitude,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  bool get isEmpty =>
      query == null &&
      categoryId == null &&
      minPrice == null &&
      maxPrice == null &&
      !verifiedOwnersOnly &&
      minRating == null;
}
