import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessagingRepository {
  final _db = FirebaseFirestore.instance;

  String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<String> getOrCreateConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final convId = conversationId(currentUserId, otherUserId);
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

  Future<void> sendMessage(
    String convId,
    String senderId,
    String otherUserId,
    String text, {
    List<String>? allParticipantIds,
  }) async {
    final convRef = _db.collection('conversations').doc(convId);
    final msgRef = convRef.collection('messages').doc();

    final recipients = allParticipantIds != null
        ? allParticipantIds.where((id) => id != senderId).toList()
        : [otherUserId];

    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(convRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      for (final id in recipients) 'unreadCount.$id': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Stream<List<ConversationModel>> getConversations(String userId) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final convs = snap.docs
          .map((doc) => ConversationModel.fromDoc(doc))
          .toList();
      convs.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      return convs;
    });
  }

  Stream<List<MessageModel>> getMessages(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromDoc(doc))
            .toList());
  }

  Future<void> markAsRead(String convId, String userId) async {
    await _db.collection('conversations').doc(convId).update({
      'unreadCount.$userId': 0,
    });
  }
}
