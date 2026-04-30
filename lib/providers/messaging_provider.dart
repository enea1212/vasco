import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../repository/messaging_repository.dart';

class MessagingProvider extends ChangeNotifier {
  final MessagingRepository _repo;

  List<ConversationModel> _conversations = [];
  StreamSubscription<List<ConversationModel>>? _convSub;

  List<ConversationModel> get conversations => _conversations;

  int totalUnread(String userId) =>
      _conversations.fold(0, (sum, c) => sum + c.unreadFor(userId));

  MessagingProvider(this._repo);

  void init(String userId) {
    _convSub?.cancel();
    _convSub = _repo.getConversations(userId).listen((convs) {
      _conversations = convs;
      notifyListeners();
    });
  }

  Future<String> openChat(String currentUserId, String otherUserId) {
    return _repo.getOrCreateConversation(currentUserId, otherUserId);
  }

  Future<void> sendMessage(
    String convId,
    String senderId,
    String otherUserId,
    String text,
  ) {
    return _repo.sendMessage(convId, senderId, otherUserId, text);
  }

  Future<void> markAsRead(String convId, String userId) {
    return _repo.markAsRead(convId, userId);
  }

  @override
  void dispose() {
    _convSub?.cancel();
    super.dispose();
  }
}
