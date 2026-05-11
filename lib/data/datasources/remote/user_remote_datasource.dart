import 'package:cloud_firestore/cloud_firestore.dart';

class UserRemoteDatasource {
  const UserRemoteDatasource(this._db);
  final FirebaseFirestore _db;

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  Stream<Map<String, dynamic>?> watchUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  Future<void> saveUser(Map<String, dynamic> data) async {
    await _db.collection('users').doc(data['id'] as String).set(data);
  }

  Future<void> saveUserMerge(String userId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateUser(String userId, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(userId).update(fields);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String lowerQuery) async {
    final snap = await _db
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: lowerQuery)
        .limit(20)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Updates the geohash-based location nested inside the user document.
  /// Used by tinder_location_service (swipe proximity matching).
  Future<void> updateUserLocation(
    String userId, {
    required String geohash,
    required double lat,
    required double lng,
  }) async {
    await _db.collection('users').doc(userId).update({
      'location': {'geohash': geohash, 'lat': lat, 'lng': lng},
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
}
