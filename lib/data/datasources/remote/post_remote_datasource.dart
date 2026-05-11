import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PostRemoteDatasource {
  const PostRemoteDatasource(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // ─── Feed (location_photos) ───────────────────────────────────────────────

  /// Main feed: last 40 location_photos ordered by createdAt desc.
  Stream<List<Map<String, dynamic>>> watchFeed() {
    return _db
        .collection('location_photos')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Single fetch of the feed from server (cache-bypass).
  Future<List<Map<String, dynamic>>> fetchFeed() async {
    final snap = await _db
        .collection('location_photos')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .get(const GetOptions(source: Source.server));
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// All location_photos, optionally filtered by userId.
  Future<List<Map<String, dynamic>>> fetchAllPhotos({
    String? onlyUserId,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('location_photos');
    if (onlyUserId != null) {
      q = q.where('userId', isEqualTo: onlyUserId);
    }
    final snap = await q.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ─── Posts collection ─────────────────────────────────────────────────────

  Future<void> createPost(Map<String, dynamic> data) async {
    final docId = data['id'] as String?;
    if (docId != null && docId.isNotEmpty) {
      await _db.collection('posts').doc(docId).set(data);
    } else {
      await _db.collection('posts').add(data);
    }
  }

  Future<void> editPost(String postId, Map<String, dynamic> fields) async {
    await _db.collection('posts').doc(postId).update(fields);
  }

  /// Deletion delegates to Cloud Function to also clean up Storage.
  Future<void> deletePost(String postId) async {
    final callable = _functions.httpsCallable('deletePost');
    await callable.call({'postId': postId});
  }

  // ─── Location photos write ────────────────────────────────────────────────

  Future<void> createLocationPhoto(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('location_photos').doc(id).set(data);
  }
}
