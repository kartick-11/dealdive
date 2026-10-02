import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

/// Debug-only helper: seeds sample deals into Firestore.
class DealSeeder {
  static Future<void> insertSampleData() async {
    final firestore = FirebaseFirestore.instance;

    final sampleDeals = <Map<String, dynamic>>[
      {
        'title': '50% OFF Large Pizza',
        'storeName': 'Mario\'s Pizza on Robson',
        'category': 'Food',
        'price': 12.99,
        'latitude': 49.2835,
        'longitude': -123.1200,
        'description':
            'Large pepperoni or veggie pizza at half price from 3–6 PM.',
        'imageUrl':
            'https://images.unsplash.com/photo-1601924928585-cf3f3f1a79d2',
        'isHot': true,
      },
      {
        'title': 'Fresh Veggie Sale',
        'storeName': 'Urban Market Granville',
        'category': 'Grocery',
        'price': 4.99,
        'latitude': 49.2730,
        'longitude': -123.1215,
        'description':
            'Organic greens and seasonal vegetables on weekly special.',
        'imageUrl':
            'https://images.unsplash.com/photo-1506801310323-534be5e7c72e',
        'isHot': false,
      },
      {
        'title': 'Gas Discount – 10¢ OFF/Litre',
        'storeName': 'Shell Kingsway & Knight',
        'category': 'Gas',
        'price': 1.68,
        'latitude': 49.2445,
        'longitude': -123.0650,
        'description': 'Save 10 cents per litre all afternoon today.',
        'imageUrl':
            'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
        'isHot': false,
      },
      {
        'title': 'Student Burrito Combo',
        'storeName': 'Burrito Brothers Cambie',
        'category': 'Student',
        'price': 7.50,
        'latitude': 49.2635,
        'longitude': -123.1140,
        'description':
            'Student ID deal: burrito + drink combo at a special price.',
        'imageUrl':
            'https://images.unsplash.com/photo-1600891964599-f61ba0e24092',
        'isHot': true,
      },
      {
        'title': '50% OFF Running Shoes',
        'storeName': 'Sportline Downtown',
        'category': 'Retail',
        'price': 49.99,
        'latitude': 49.2860,
        'longitude': -123.1180,
        'description':
            'Selected men’s and women’s running shoes at half price.',
        'imageUrl':
            'https://images.unsplash.com/photo-1600185365483-26d42f73877f',
        'isHot': true,
      },
      {
        'title': '2-for-1 Latte Happy Hour',
        'storeName': 'Bean & Brew Coffee',
        'category': 'Food',
        'price': 5.50,
        'latitude': 49.2705,
        'longitude': -123.1000,
        'description':
            '2-for-1 handcrafted lattes from 2–5 PM, weekdays only.',
        'imageUrl':
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085',
        'isHot': true,
      },
    ];

    final batch = firestore.batch();

    for (final deal in sampleDeals) {
      final docRef = firestore.collection('deals').doc();
      batch.set(docRef, deal);
      debugPrint('Inserted deal: ${deal['title']}');
    }

    await batch.commit();
    debugPrint('✅ Seed data inserted successfully.');
  }
}
