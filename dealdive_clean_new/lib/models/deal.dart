class Deal {
  final String id;
  final String title;
  final String storeName;
  final String category;
  final double price;

  // Required coordinates for map + distance
  final double latitude;
  final double longitude;

  // Optional extras
  final String? description;
  final String? imageUrl;

  // Top deals flag
  final bool isHot;

  // Happy Hour-specific metadata (null for other categories)
  final String? day;
  final String? neighbourhood;

  // Black Friday-specific metadata (null for other categories)
  final String? mall;

  // City this deal applies to. Null means it applies broadly (e.g. a
  // national app promo) rather than one specific location.
  final String? city;

  Deal({
    required this.id,
    required this.title,
    required this.storeName,
    required this.category,
    required this.price,
    required this.latitude,
    required this.longitude,
    this.description,
    this.imageUrl,
    this.isHot = false,
    this.day,
    this.neighbourhood,
    this.mall,
    this.city,
  });

  /// Factory constructor to create a Deal from Firestore data
  factory Deal.fromFirestore(String id, Map<String, dynamic> data) {
    // Helper that safely converts to double (supports int, double, null)
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return Deal(
      id: id,
      title: data['title'] as String? ?? 'Untitled deal',
      storeName: data['storeName'] as String? ?? 'Unknown store',
      category: data['category'] as String? ?? 'Other',
      price: parseDouble(data['price']),

      // Latitude / longitude stored in Firestore as "latitude", "longitude"
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),

      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      isHot: data['isHot'] as bool? ?? false,

      day: data['day'] as String?,
      neighbourhood: data['neighbourhood'] as String?,
      mall: data['mall'] as String?,
      city: data['city'] as String?,
    );
  }

  /// Converts the deal to a Firestore-friendly map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'storeName': storeName,
      'category': category,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'imageUrl': imageUrl,
      'isHot': isHot,
      'day': day,
      'neighbourhood': neighbourhood,
      'mall': mall,
      'city': city,
    };
  }
}