import 'package:cloud_firestore/cloud_firestore.dart';

class LocationRemoteDatasource {
  const LocationRemoteDatasource(this._db);
  final FirebaseFirestore _db;

  // ─── Friend locations ─────────────────────────────────────────────────────

  /// Watches the user_locations document for a single friend.
  Stream<Map<String, dynamic>?> watchFriendLocation(String friendId) {
    return _db
        .collection('user_locations')
        .doc(friendId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  /// Watches friends subcollection and returns the list of friend user IDs.
  Stream<List<String>> watchFriendIds(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d['userId'] as String).toList());
  }

  // ─── Publishing own location ──────────────────────────────────────────────

  Future<void> publishLocation(
    String userId,
    double lat,
    double lng,
    String sharedGroupId,
  ) async {
    await _db.collection('user_locations').doc(userId).set({
      'latitude': lat,
      'longitude': lng,
      'updatedAt': FieldValue.serverTimestamp(),
      'sharedGroupId': sharedGroupId,
    }, SetOptions(merge: true));
  }

  Future<void> deleteLocation(String userId) async {
    await _db.collection('user_locations').doc(userId).delete();
  }

  // ─── Visibility (sharedGroupId) ───────────────────────────────────────────

  /// Returns the current sharedGroupId value, or 'none' if no doc exists.
  Future<String> getVisibility(String userId) async {
    final doc =
        await _db.collection('user_locations').doc(userId).get();
    if (!doc.exists) return 'none';
    return (doc.data()?['sharedGroupId'] as String?) ?? 'all';
  }

  /// Sets visibility: 'none' deletes the location doc; anything else merges
  /// the sharedGroupId field.
  Future<void> setVisibility(String userId, String visibility) async {
    if (visibility == 'none') {
      await deleteLocation(userId);
    } else {
      await _db.collection('user_locations').doc(userId).set(
        {'sharedGroupId': visibility},
        SetOptions(merge: true),
      );
    }
  }

  // ─── Location groups ──────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchLocationGroups(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .orderBy('createdAt')
        .snapshots()
        .asyncMap((snap) async {
      final result = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final membersSnap =
            await doc.reference.collection('members').get();
        result.add({
          'id': doc.id,
          'name': doc['name'] as String,
          'memberIds': membersSnap.docs
              .map((m) => m['userId'] as String)
              .toList(),
        });
      }
      return result;
    });
  }

  Future<String> createLocationGroup(
    String userId,
    String name,
    List<String> memberIds,
  ) async {
    final groupRef = _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .doc();
    final batch = _db.batch();
    batch.set(groupRef, {
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final memberId in memberIds) {
      batch.set(groupRef.collection('members').doc(memberId), {
        'userId': memberId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return groupRef.id;
  }

  Future<void> deleteLocationGroup(String userId, String groupId) async {
    final groupRef = _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .doc(groupId);
    final members = await groupRef.collection('members').get();
    final batch = _db.batch();
    for (final m in members.docs) {
      batch.delete(m.reference);
    }
    batch.delete(groupRef);
    await batch.commit();
  }

  Future<void> addGroupMember(
    String userId,
    String groupId,
    String memberId,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .doc(groupId)
        .collection('members')
        .doc(memberId)
        .set({'userId': memberId, 'addedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeGroupMember(
    String userId,
    String groupId,
    String memberId,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .doc(groupId)
        .collection('members')
        .doc(memberId)
        .delete();
  }
}
