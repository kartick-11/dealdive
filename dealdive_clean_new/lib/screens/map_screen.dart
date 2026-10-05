import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/deal.dart';
import '../models/nearby_place.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import '../utils/distance_utils.dart';
import 'deal_detail_screen.dart';

// Standard Google "night mode" style JSON, applied to the map when the app
// is in dark theme so the map doesn't stay a glaring white rectangle inside
// an otherwise dark UI.
const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
  {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
]
''';

class MapScreen extends StatefulWidget {
  final String selectedCategory;
  final Deal? focusDeal;
  final Set<String> savedDealIds;
  final void Function(Deal) onToggleSaved;

  const MapScreen({
    super.key,
    required this.selectedCategory,
    required this.focusDeal,
    required this.savedDealIds,
    required this.onToggleSaved,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const CameraPosition _vancouver = CameraPosition(
    target: LatLng(49.2827, -123.1207),
    zoom: 12,
  );

  final Completer<GoogleMapController> _mapController = Completer();

  Position? _userPosition;
  bool _isLoadingLocation = false;

  List<NearbyPlace> _nearbyPlaces = [];
  bool _isLoadingPlaces = false;

  double _currentZoom = 12;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    // Re-style the map whenever the app's light/dark toggle changes,
    // not just on first load.
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (!mounted) return;
    _applyMapStyle();
  }

  bool _isDarkMode() {
    final mode = AppTheme.themeModeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> _applyMapStyle() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.setMapStyle(_isDarkMode() ? _darkMapStyle : null);
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLoadingLocation = true);

    final pos = await LocationService.getCurrentPosition();

    if (!mounted) return;

    setState(() {
      _userPosition = pos;
      _isLoadingLocation = false;
    });

    if (pos != null) {
      _loadNearbyPlaces(pos);
    }
  }

  Future<void> _loadNearbyPlaces(Position pos) async {
    setState(() => _isLoadingPlaces = true);

    try {
      final places = await PlacesService.getNearbyPlaces(
        lat: pos.latitude,
        lng: pos.longitude,
        type: 'restaurant',
      );

      if (!mounted) return;

      setState(() {
        _nearbyPlaces = places;
      });
    } catch (e) {
      debugPrint('Error loading places: $e');
    }

    if (!mounted) return;
    setState(() => _isLoadingPlaces = false);
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusDeal != null &&
        widget.focusDeal != oldWidget.focusDeal) {
      _animateToDeal(widget.focusDeal!);
    }
  }

  Future<void> _animateToDeal(Deal deal) async {
    if (!_mapController.isCompleted) return;

    final controller = await _mapController.future;

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(deal.latitude, deal.longitude),
          zoom: 14,
        ),
      ),
    );
  }

  Future<void> _recenterOnUser() async {
    if (_userPosition == null || !_mapController.isCompleted) return;

    final controller = await _mapController.future;

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _userPosition!.latitude,
            _userPosition!.longitude,
          ),
          zoom: 14,
        ),
      ),
    );
  }

  Future<void> _zoomIn() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    _currentZoom += 1;
    controller.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }

  Future<void> _zoomOut() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    _currentZoom -= 1;
    controller.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }

  CameraPosition _initialCameraPosition() {
    if (widget.focusDeal != null) {
      return CameraPosition(
        target: LatLng(
          widget.focusDeal!.latitude,
          widget.focusDeal!.longitude,
        ),
        zoom: 14,
      );
    }

    if (_userPosition != null) {
      return CameraPosition(
        target: LatLng(
          _userPosition!.latitude,
          _userPosition!.longitude,
        ),
        zoom: 13,
      );
    }

    return _vancouver;
  }

  /// Opens the deal detail screen for a tapped marker. "View on map" from
  /// that screen just pops back here and re-centers on the same deal,
  /// since we're already on the Map tab.
  void _openDealDetail(Deal deal) {
    final distanceKm = _userPosition == null
        ? null
        : calculateDistanceKm(
            userLat: _userPosition!.latitude,
            userLng: _userPosition!.longitude,
            dealLat: deal.latitude,
            dealLng: deal.longitude,
          );
    final distanceText =
        distanceKm == null ? null : '${distanceKm.toStringAsFixed(1)} km away';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DealDetailScreen(
          deal: deal,
          isSaved: widget.savedDealIds.contains(deal.id),
          onToggleSaved: widget.onToggleSaved,
          onViewOnMap: (d) {
            Navigator.of(context).pop();
            _animateToDeal(d);
          },
          distanceText: distanceText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('deals')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final deals = snapshot.data!.docs
                  .map((d) => Deal.fromFirestore(d.id, d.data()))
                  .where((deal) {
                if (widget.selectedCategory == 'All') return true;
                return deal.category.toLowerCase() ==
                    widget.selectedCategory.toLowerCase();
              }).toList();

              final dealMarkers = deals.map((deal) {
                final isSaved =
                    widget.savedDealIds.contains(deal.id);

                final hue = isSaved
                    ? BitmapDescriptor.hueAzure
                    : BitmapDescriptor.hueRed;

                String snippet =
                    '${deal.storeName} • \$${deal.price.toStringAsFixed(2)}';

                if (_userPosition != null) {
                  final km = calculateDistanceKm(
                    userLat: _userPosition!.latitude,
                    userLng: _userPosition!.longitude,
                    dealLat: deal.latitude,
                    dealLng: deal.longitude,
                  );
                  snippet += ' • ${km.toStringAsFixed(1)} km away';
                }

                return Marker(
                  markerId: MarkerId('deal_${deal.id}'),
                  position: LatLng(deal.latitude, deal.longitude),
                  infoWindow: InfoWindow(
                    title: deal.title,
                    snippet: snippet,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                  // Tapping the pin itself goes straight to the deal's
                  // detail screen, instead of only showing the info bubble.
                  onTap: () => _openDealDetail(deal),
                );
              }).toSet();

              final placeMarkers = _nearbyPlaces.map((place) {
                return Marker(
                  markerId: MarkerId('place_${place.placeId}'),
                  position: LatLng(place.latitude, place.longitude),
                  infoWindow: InfoWindow(
                    title: place.name,
                    snippet: place.address ?? '',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                );
              }).toSet();

              return GoogleMap(
                initialCameraPosition: _initialCameraPosition(),
                myLocationEnabled: !kIsWeb && _userPosition != null,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: {...dealMarkers, ...placeMarkers},
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  _applyMapStyle();
                },
                onCameraMove: (position) {
                  _currentZoom = position.zoom;
                },
              );
            },
          ),

          // 🔥 LOADING UI
          if (_isLoadingLocation || _isLoadingPlaces)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text("Loading map data..."),
                    ],
                  ),
                ),
              ),
            ),

          // 📍 MY LOCATION BUTTON + ➕➖ ZOOM CONTROLS
          // Stacked in one Column so their spacing is computed, not
          // guessed via separate Positioned offsets — that guesswork is
          // what let the two groups overlap before.
          Positioned(
            right: 16,
            bottom: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_userPosition != null) ...[
                  FloatingActionButton.small(
                    heroTag: 'my_location',
                    onPressed: _recenterOnUser,
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 16),
                ],
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}