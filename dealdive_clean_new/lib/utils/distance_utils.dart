import 'package:geolocator/geolocator.dart';

/// Returns distance in **kilometres** between user and deal.
double calculateDistanceKm({
  required double userLat,
  required double userLng,
  required double dealLat,
  required double dealLng,
}) {
  final distanceMeters = Geolocator.distanceBetween(
    userLat,
    userLng,
    dealLat,
    dealLng,
  );
  return distanceMeters / 1000.0;
}
