import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';

class FriendsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ─── WRITE OPERATIONS (Cloud Functions) ──────────────────────────────────

  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    final callable = _functions.httpsCallable('sendFriendRequest');
    await callable.call({'toUserId': toUserId});
  }

  Future<void> cancelFriendRequest(String fromUserId, String toUserId) async {
    final callable = _functions.httpsCallable('cancelFriendRequest');
    await callable.call({'toUserId': toUserId});
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String fromUserId,
    String toUserId,
  ) async {
    final callable = _functions.httpsCallable('acceptFriendRequest');
    await callable.call({'requestId': requestId});
  }

  Future<void> declineFriendRequest(String requestId) async {
    final callable = _functions.httpsCallable('declineFriendRequest');
    await callable.call({'requestId': requestId});
  }

  Future<void> removeFriend(String currentUserId, String friendId) async {
    final callable = _functions.httpsCallable('removeFriend');
    await callable.call({'friendId': friendId});
  }

  // ─── READ OPERATIONS (Firestore direct) ──────────────────────────────────

  Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    if (query.trim().isEmpty) return [];

    final lower = query.trim().toLowerCase();

    final snapshot = await _db
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: lower)
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
        .where((u) => u.id != currentUserId &&
            (u.displayName?.toLowerCase().contains(lower) ?? false))
        .toList();
  }

  Stream<List<FriendRequestModel>> getIncomingRequests(String userId) {
    return _db
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FriendRequestModel.fromDoc).toList());
  }

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

  Future<void> ensureDisplayNameIndex(
    String userId,
    String displayName,
  ) async {
    await _db.collection('users').doc(userId).update({
      'displayNameLower': displayName.toLowerCase(),
    });
  }
}
