import '../models/nearby_place.dart';

/// Stub implementation: we’re not using a paid backend,
/// so this just returns an empty list for now.
///
/// Your app map will still show all Firestore deals,
/// but it won’t show live Google places (green pins).
class PlacesService {
  static Future<List<NearbyPlace>> getNearbyPlaces({
    required double lat,
    required double lng,
    String type = 'restaurant',
  }) async {
    // No backend / Places API integration right now.
    // Return an empty list so the rest of the app works.
    return [];
  }
}
