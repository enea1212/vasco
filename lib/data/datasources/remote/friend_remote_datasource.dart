import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FriendRemoteDatasource {
  const FriendRemoteDatasource(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // ─── Reads ────────────────────────────────────────────────────────────────

  /// Watches friends subcollection and resolves full user docs.
  Stream<List<Map<String, dynamic>>> watchFriends(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final futures = snap.docs.map((doc) async {
            final friendId = doc['userId'] as String;
            final userDoc =
                await _db.collection('users').doc(friendId).get();
            if (!userDoc.exists) return null;
            return {'id': userDoc.id, ...userDoc.data()!};
          });
          final results = await Future.wait(futures);
          return results.whereType<Map<String, dynamic>>().toList();
        });
  }

  /// Watches incoming pending friend requests targeting [userId].
  Stream<List<Map<String, dynamic>>> watchIncomingRequests(String userId) {
    return _db
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Returns 'friends' | 'pending_sent' | 'pending_received' | 'none'.
  Future<String> getRelationshipStatus(
    String currentUserId,
    String otherUserId,
  ) async {
    final friendDoc = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(otherUserId)
        .get();
    if (friendDoc.exists) return 'friends';

    final sent = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (sent.docs.isNotEmpty) return 'pending_sent';

    final received = await _db
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: otherUserId)
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (received.docs.isNotEmpty) return 'pending_received';

    return 'none';
  }

  // ─── Cloud Function writes ────────────────────────────────────────────────

  Future<void> sendFriendRequest(String toUserId) async {
    final callable = _functions.httpsCallable('sendFriendRequest');
    await callable.call({'toUserId': toUserId});
  }

  Future<void> cancelFriendRequest(String toUserId) async {
    final callable = _functions.httpsCallable('cancelFriendRequest');
    await callable.call({'toUserId': toUserId});
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final callable = _functions.httpsCallable('acceptFriendRequest');
    await callable.call({'requestId': requestId});
  }

  Future<void> declineFriendRequest(String requestId) async {
    final callable = _functions.httpsCallable('declineFriendRequest');
    await callable.call({'requestId': requestId});
  }

  Future<void> removeFriend(String friendId) async {
    final callable = _functions.httpsCallable('removeFriend');
    await callable.call({'friendId': friendId});
  }
}
