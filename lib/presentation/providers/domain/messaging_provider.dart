import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/usecases/messaging/watch_conversations_usecase.dart';
import '../../../domain/usecases/messaging/watch_messages_usecase.dart';
import '../../../domain/usecases/messaging/send_message_usecase.dart';

class MessagingProvider extends ChangeNotifier {
  MessagingProvider(
    this._watchConversations,
    this._watchMessages,
    this._sendMessage,
  );

  final WatchConversationsUsecase _watchConversations;
  final WatchMessagesUsecase _watchMessages;
  final SendMessageUsecase _sendMessage;

  List<ConversationEntity> _conversations = [];
  List<MessageEntity> _messages = [];
  bool _isLoading = false;

  StreamSubscription<List<ConversationEntity>>? _convSub;
  StreamSubscription<List<MessageEntity>>? _msgSub;

  List<ConversationEntity> get conversations => _conversations;
  List<MessageEntity> get messages => _messages;
  bool get isLoading => _isLoading;

  int totalUnread(String userId) => _conversations.fold(
        0,
        (sum, c) => sum + (c.unreadCount[userId] ?? 0),
      );

  void init(String userId) {
    _convSub?.cancel();
    _convSub = _watchConversations(userId).listen(
      (convs) {
        _conversations = convs;
        notifyListeners();
      },
      onError: (_) {
        _conversations = [];
        notifyListeners();
      },
    );
  }

  void loadMessages(String conversationId) {
    _msgSub?.cancel();
    _msgSub = _watchMessages(conversationId).listen(
      (msgs) {
        _messages = msgs;
        notifyListeners();
      },
    );
  }

  Future<void> sendMessage(String conversationId, MessageEntity msg) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _sendMessage(conversationId, msg);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }
}
