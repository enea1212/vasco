import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PostRemoteDatasource {
  const PostRemoteDatasource(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // ─── Feed (location_photos) ───────────────────────────────────────────────

  /// Posts where `userId == X` OR `acceptedCoAuthorIds array-contains X`,
  /// merged client-side and sorted by createdAt desc.
  Stream<List<Map<String, dynamic>>> watchUserPosts(String userId) {
    final ownStream = _db
        .collection('location_photos')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    final coAuthorStream = _db
        .collection('location_photos')
        .where('acceptedCoAuthorIds', arrayContains: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    return _mergeAndSort(ownStream, coAuthorStream);
  }

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

  /// Posts from a specific set of user IDs (≤ 30 per Firestore whereIn limit)
  /// merged with posts where any of those users are accepted co-authors.
  /// Sorted client-side by createdAt desc.
  Stream<List<Map<String, dynamic>>> watchPostsByUserIds(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    final ids = userIds.length > 30 ? userIds.sublist(0, 30) : userIds;

    final ownStream = _db
        .collection('location_photos')
        .where('userId', whereIn: ids)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    final coAuthorStream = _db
        .collection('location_photos')
        .where('acceptedCoAuthorIds', arrayContainsAny: ids)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    return _mergeAndSort(ownStream, coAuthorStream);
  }

  // ─── Location photos write ────────────────────────────────────────────────

  Future<void> createLocationPhoto(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('location_photos').doc(id).set(data);
  }

  // ─── Co-authoring ─────────────────────────────────────────────────────────

  /// Posts where `pendingCoAuthorIds array-contains userId` —
  /// i.e. requests awaiting a response from this user.
  Stream<List<Map<String, dynamic>>> watchPendingCoAuthorRequests(
    String userId,
  ) {
    return _db
        .collection('location_photos')
        .where('pendingCoAuthorIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList()
            ..sort((a, b) {
              final ta = (a['createdAt'] as Timestamp?)?.seconds ?? 0;
              final tb = (b['createdAt'] as Timestamp?)?.seconds ?? 0;
              return tb.compareTo(ta);
            });
          return list;
        });
  }

  /// Move user from `pendingCoAuthorIds` to `acceptedCoAuthorIds`.
  Future<void> acceptCoAuthorRequest(String postId, String userId) async {
    await _db.collection('location_photos').doc(postId).update({
      'pendingCoAuthorIds': FieldValue.arrayRemove([userId]),
      'acceptedCoAuthorIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove user from `pendingCoAuthorIds` (declined — no add elsewhere).
  Future<void> declineCoAuthorRequest(String postId, String userId) async {
    await _db.collection('location_photos').doc(postId).update({
      'pendingCoAuthorIds': FieldValue.arrayRemove([userId]),
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Combines two streams of posts; emits a deduped + sorted list each time
  /// either side produces an update.
  Stream<List<Map<String, dynamic>>> _mergeAndSort(
    Stream<List<Map<String, dynamic>>> a,
    Stream<List<Map<String, dynamic>>> b,
  ) {
    List<Map<String, dynamic>> latestA = const [];
    List<Map<String, dynamic>> latestB = const [];
    final controller =
        StreamController<List<Map<String, dynamic>>>.broadcast();

    void emit() {
      final byId = <String, Map<String, dynamic>>{};
      for (final p in latestA) {
        final id = p['id'] as String?;
        if (id != null) byId[id] = p;
      }
      for (final p in latestB) {
        final id = p['id'] as String?;
        if (id != null) byId.putIfAbsent(id, () => p);
      }
      final merged = byId.values.toList()
        ..sort((x, y) {
          final tx = (x['createdAt'] as Timestamp?)?.seconds ?? 0;
          final ty = (y['createdAt'] as Timestamp?)?.seconds ?? 0;
          return ty.compareTo(tx);
        });
      controller.add(merged);
    }

    final subA = a.listen(
      (v) {
        latestA = v;
        emit();
      },
      onError: controller.addError,
    );
    final subB = b.listen(
      (v) {
        latestB = v;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };

    return controller.stream;
  }
}
