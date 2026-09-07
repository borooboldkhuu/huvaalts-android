import 'dart:math' as math;

/// Pure-Dart geo helpers — no PostGIS/plugin dependency. Used for
/// client-side "closest first" sorting where the DB schema doesn't yet
/// have a geospatial index (spec section 13's Map view, when it lands,
/// should move this server-side via PostGIS `ST_Distance` for anything
/// beyond a small in-memory batch).
class GeoUtils {
  const GeoUtils._();

  static const double _earthRadiusKm = 6371.0088;

  /// Great-circle distance between two lat/lng points, in kilometers.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final double dLat = _degToRad(lat2 - lat1);
    final double dLng = _degToRad(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
