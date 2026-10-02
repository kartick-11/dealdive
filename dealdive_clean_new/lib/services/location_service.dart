import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Gets the user's current position, or null if unavailable / denied.
  static Future<Position?> getCurrentPosition() async {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // In a real app you might show a dialog/snackbar here.
      return null;
    }

    // 2. Check permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User still denied permission.
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, handle appropriately in UI.
      return null;
    }

    // 3. Use LocationSettings (non-deprecated way)
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters – tweak if needed
    );

    return Geolocator.getCurrentPosition(
      locationSettings: settings,
    );
  }
}
