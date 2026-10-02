import 'package:cloud_firestore/cloud_firestore.dart';

class SavedDealsService {
  final String userId;
  final _firestore = FirebaseFirestore.instance;

  SavedDealsService({required this.userId});

  /// Path: users/{userId}/savedDeals/{dealId}
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(userId).collection('savedDeals');

  /// Load all saved deal IDs once.
  Future<Set<String>> getSavedDealIds() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  /// Stream of saved deal IDs — stays in sync across devices/sessions.
  Stream<Set<String>> savedDealIdsStream() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  /// Set whether a deal is saved or not.
  Future<void> setSaved(String dealId, bool isSaved) async {
    final docRef = _collection.doc(dealId);
    if (isSaved) {
      await docRef.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }
}