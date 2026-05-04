import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationGroup {
  final String id;
  final String name;
  final List<String> memberIds;

  const LocationGroup({
    required this.id,
    required this.name,
    required this.memberIds,
  });
}

class LocationGroupsService {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Stream<List<LocationGroup>> watchGroups(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('location_groups')
        .orderBy('createdAt')
        .snapshots()
        .asyncMap((snap) async {
      final groups = <LocationGroup>[];
      for (final doc in snap.docs) {
        final membersSnap = await doc.reference.collection('members').get();
        groups.add(LocationGroup(
          id: doc.id,
          name: doc['name'] as String,
          memberIds:
              membersSnap.docs.map((m) => m['userId'] as String).toList(),
        ));
      }
      return groups;
    });
  }

  static Future<String> createGroup(
      String name, List<String> memberIds) async {
    final uid = _uid;
    if (uid == null) throw Exception('Autentificare necesară.');

    final groupRef = _db
        .collection('users')
        .doc(uid)
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

  static Future<void> deleteGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Autentificare necesară.');

    final groupRef = _db
        .collection('users')
        .doc(uid)
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

  static Future<void> addMember(String groupId, String memberId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Autentificare necesară.');

    await _db
        .collection('users')
        .doc(uid)
        .collection('location_groups')
        .doc(groupId)
        .collection('members')
        .doc(memberId)
        .set({'userId': memberId, 'addedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> removeMember(String groupId, String memberId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Autentificare necesară.');

    await _db
        .collection('users')
        .doc(uid)
        .collection('location_groups')
        .doc(groupId)
        .collection('members')
        .doc(memberId)
        .delete();
  }

  static Future<void> setVisibility(String userId, String visibility) async {
    if (visibility == 'none') {
      await _db.collection('user_locations').doc(userId).delete();
    } else {
      await _db.collection('user_locations').doc(userId).set(
        {'sharedGroupId': visibility},
        SetOptions(merge: true),
      );
    }
  }

  static Future<String> getVisibility(String userId) async {
    final doc = await _db.collection('user_locations').doc(userId).get();
    if (!doc.exists) return 'none';
    return (doc.data()?['sharedGroupId'] as String?) ?? 'all';
  }
}
