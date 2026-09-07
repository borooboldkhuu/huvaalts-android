import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Best-effort device location for the Home "Ойролцоо / Nearby" section.
/// Deliberately never throws and never prompts aggressively — if location
/// services are off, permission is denied, or the fix times out, this
/// resolves to `null` and [HomeScreen] simply omits the Nearby section
/// rather than showing an error or blocking the rest of Home (spec section
/// 43: every screen needs a real "this feature just isn't available right
/// now" path, not just happy-path handling).
///
/// Requires `ACCESS_COARSE_LOCATION` (AndroidManifest.xml) and
/// `NSLocationWhenInUseUsageDescription` (Info.plist) once the platform
/// projects exist — see README "Known issues".
final FutureProvider<(double, double)?> nearbyLocationProvider =
    FutureProvider<(double, double)?>((ref) async {
  try {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return (position.latitude, position.longitude);
  } catch (_) {
    // Any platform-channel/permission/timeout failure: treat as "no
    // location available" rather than surfacing an error for a
    // non-essential, best-effort section.
    return null;
  }
});
