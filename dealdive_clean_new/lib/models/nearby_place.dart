class NearbyPlace {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final double? rating;

  NearbyPlace({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.rating,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return NearbyPlace(
      placeId: json['placeId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown place',
      latitude: parseDouble(json['lat']),
      longitude: parseDouble(json['lng']),
      address: json['address'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}
