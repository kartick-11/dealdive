import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/deal.dart';
import '../services/location_service.dart';
import '../utils/distance_utils.dart';
import 'deal_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  final Set<String> savedDealIds;
  final void Function(Deal) onViewOnMap;
  final void Function(Deal) onToggleSaved;

  const SavedScreen({
    super.key,
    required this.savedDealIds,
    required this.onViewOnMap,
    required this.onToggleSaved,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  Position? _userPosition;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    final pos = await LocationService.getCurrentPosition();

    setState(() {
      _userPosition = pos;
      _isLoadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.savedDealIds.isEmpty) {
      return const Center(
        child: Text(
          'No saved deals yet.\nTap the bookmark icon on any deal to save it.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        if (_isLoadingLocation)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Getting your location...',
              style: TextStyle(fontSize: 12),
            ),
          )
        else if (_userPosition == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Location unavailable. Distance will be hidden.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('deals')
                .snapshots(), // simple approach, filter client-side
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading saved deals',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final deals = docs
                  .map((doc) => Deal.fromFirestore(doc.id, doc.data()))
                  .where((deal) => widget.savedDealIds.contains(deal.id))
                  .toList();

              if (deals.isEmpty) {
                return const Center(
                  child: Text(
                    'No saved deals found.\nThey may have expired or been removed.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: deals.length,
                itemBuilder: (context, index) {
                  final deal = deals[index];

                  String? distanceText;
                  if (_userPosition != null) {
                    final km = calculateDistanceKm(
                      userLat: _userPosition!.latitude,
                      userLng: _userPosition!.longitude,
                      dealLat: deal.latitude,
                      dealLng: deal.longitude,
                    );
                    distanceText = '${km.toStringAsFixed(1)} km away';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(deal.title),
                      subtitle: Text(
                        distanceText == null
                            ? '${deal.storeName} • ${deal.category}'
                            : '${deal.storeName} • ${deal.category} • $distanceText',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.map_outlined),
                        onPressed: () => widget.onViewOnMap(deal),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DealDetailScreen(
                              deal: deal,
                              isSaved: true,
                              distanceText: distanceText,
                              onToggleSaved: widget.onToggleSaved,
                              onViewOnMap: widget.onViewOnMap,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
