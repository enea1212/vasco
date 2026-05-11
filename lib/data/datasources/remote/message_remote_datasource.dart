import 'package:cloud_firestore/cloud_firestore.dart';

class MessageRemoteDatasource {
  const MessageRemoteDatasource(this._db);
  final FirebaseFirestore _db;

  // ─── Conversations ────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchConversations(String userId) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> getOrCreateConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final sorted = [currentUserId, otherUserId]..sort();
    final convId = '${sorted[0]}_${sorted[1]}';
    final ref = _db.collection('conversations').doc(convId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participantIds': [currentUserId, otherUserId],
        'isGroup': false,
        'lastMessage': '',
        'lastMessageTime': null,
        'lastMessageSenderId': '',
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return convId;
  }

  Future<String> createGroupConversation(
    String currentUserId,
    List<String> memberIds,
    String name,
  ) async {
    final allParticipants = [currentUserId, ...memberIds];
    final ref = _db.collection('conversations').doc();
    await ref.set({
      'participantIds': allParticipants,
      'isGroup': true,
      'name': name.trim(),
      'lastMessage': '',
      'lastMessageTime': null,
      'lastMessageSenderId': '',
      'unreadCount': {for (final id in allParticipants) id: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> sendMessage(
    String convId,
    String senderId,
    String text, {
    List<String>? allParticipantIds,
    String? otherUserId,
  }) async {
    final convRef = _db.collection('conversations').doc(convId);
    final msgRef = convRef.collection('messages').doc();

    final recipients = allParticipantIds != null
        ? allParticipantIds.where((id) => id != senderId).toList()
        : [if (otherUserId case final id?) id];

    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(convRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      for (final id in recipients)
        'unreadCount.$id': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$userId': 0,
    });
  }
}
