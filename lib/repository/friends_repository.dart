import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';

class FriendsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Caută utilizatori după nume (case-insensitive prefix search)
  Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    if (query.trim().isEmpty) return [];

    final lower = query.trim().toLowerCase();
    final upper = lower + '';

    final snapshot = await _db
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: lower)
        .where('displayNameLower', isLessThanOrEqualTo: upper)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return UserModel(
            id: data['id'] ?? doc.id,
            email: data['email'] ?? '',
            displayName: data['displayName'],
            photoUrl: data['photoUrl'],
            biography: data['bio'],
          );
        })
        .where((u) => u.id != currentUserId)
        .toList();
  }

  // Trimite cerere de prietenie
  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    // Verifică dacă există deja o cerere
    final existing = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    final request = FriendRequestModel(
      id: '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _db.collection('friend_requests').add(request.toMap());
  }

  // Anulează o cerere trimisă
  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    final snapshot = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Acceptă cererea: șterge request, adaugă în sub-colecțiile friends ale ambilor
  Future<void> acceptFriendRequest(String requestId, String fromUserId, String toUserId) async {
    final batch = _db.batch();

    batch.delete(_db.collection('friend_requests').doc(requestId));

    final now = Timestamp.now();

    batch.set(
      _db.collection('users').doc(toUserId).collection('friends').doc(fromUserId),
      {'userId': fromUserId, 'addedAt': now},
    );
    batch.set(
      _db.collection('users').doc(fromUserId).collection('friends').doc(toUserId),
      {'userId': toUserId, 'addedAt': now},
    );

    await batch.commit();
  }

  // Refuză și șterge cererea
  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  // Elimină un prieten
  Future<void> removeFriend(String currentUserId, String friendId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(currentUserId).collection('friends').doc(friendId));
    batch.delete(_db.collection('users').doc(friendId).collection('friends').doc(currentUserId));
    await batch.commit();
  }

  // Stream cu cererile primite (pending)
  Stream<List<FriendRequestModel>> getIncomingRequests(String userId) {
    return _db
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequestModel.fromDoc).toList());
  }

  // Stream cu lista de prieteni (ca UserModel)
  Stream<List<UserModel>> getFriends(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final futures = snap.docs.map((doc) async {
            final friendId = doc['userId'] as String;
            final userDoc = await _db.collection('users').doc(friendId).get();
            if (!userDoc.exists) return null;
            final data = userDoc.data()!;
            return UserModel(
              id: data['id'] ?? userDoc.id,
              email: data['email'] ?? '',
              displayName: data['displayName'],
              photoUrl: data['photoUrl'],
              biography: data['bio'],
            );
          });
          final results = await Future.wait(futures);
          return results.whereType<UserModel>().toList();
        });
  }

  // Returnează starea relației dintre doi utilizatori
  // 'none' | 'pending_sent' | 'pending_received' | 'friends'
  Future<String> getRelationshipStatus(String currentUserId, String otherUserId) async {
    // Verifică prietenie
    final friendDoc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(otherUserId)
        .get();
    if (friendDoc.exists) return 'friends';

    // Verifică cerere trimisă
    final sent = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sent.docs.isNotEmpty) return 'pending_sent';

    // Verifică cerere primită
    final received = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: otherUserId)
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (received.docs.isNotEmpty) return 'pending_received';

    return 'none';
  }

  // Obține un utilizator după ID
  Future<UserModel?> fetchUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return UserModel(
        id: data['id'] ?? doc.id,
        email: data['email'] ?? '',
        displayName: data['displayName'],
        photoUrl: data['photoUrl'],
        biography: data['bio'],
      );
    } catch (_) {
      return null;
    }
  }

  // Salvează displayNameLower la înregistrare/update (util pentru search)
  Future<void> ensureDisplayNameIndex(String userId, String displayName) async {
    await _db.collection('users').doc(userId).update({
      'displayNameLower': displayName.toLowerCase(),
    });
  }
}
