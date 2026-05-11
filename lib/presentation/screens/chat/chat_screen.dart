import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/models/message_model.dart';
import 'package:vasco/providers/messaging_provider.dart';
import 'package:vasco/repository/messaging_repository.dart';
import 'package:vasco/screens/user_profile_screen.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String? groupName;
  final List<String>? groupParticipantIds;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUserPhoto,
    this.groupName,
    this.groupParticipantIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _repo = MessagingRepository();

  List<MessageModel> _messages = [];
  StreamSubscription<List<MessageModel>>? _msgSub;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgSub = _repo
        .getMessages(widget.conversationId)
        .listen(
          (msgs) {
            if (mounted) {
              setState(() => _messages = msgs);
              _scrollToBottom();
            }
          },
          onError: (error, stackTrace) {
            debugPrint('[ChatScreen] messages stream error: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Nu pot încărca mesajele: $error')),
              );
            }
          },
        );
    unawaited(
      context
          .read<MessagingProvider>()
          .markAsRead(widget.conversationId, widget.currentUserId)
          .catchError((error) {
            debugPrint('Eroare la marcarea mesajelor ca citite: $error');
          }),
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(
        widget.conversationId,
        widget.currentUserId,
        widget.otherUserId,
        text,
        allParticipantIds: widget.groupParticipantIds,
      );
    } catch (e) {
      if (!mounted) return;
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut trimite mesajul: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: widget.groupName != null
            ? Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      size: 18,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.groupName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: widget.otherUserId,
                      initialDisplayName: widget.otherUserName,
                      initialPhotoUrl: widget.otherUserPhoto,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: widget.otherUserPhoto != null
                          ? NetworkImage(widget.otherUserPhoto!)
                          : null,
                      backgroundColor: const Color(0xFFF3F4F6),
                      child: widget.otherUserPhoto == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      msg: _messages[i],
                      isMe: _messages[i].senderId == widget.currentUserId,
                      showTime:
                          i == 0 ||
                          _messages[i].createdAt
                                  .difference(_messages[i - 1].createdAt)
                                  .inMinutes >
                              10,
                    ),
                  ),
          ),
          _InputBar(controller: _controller, sending: _sending, onSend: _send),
        ],
      ),
    );
  }

  Widget _emptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: widget.otherUserPhoto != null
                ? NetworkImage(widget.otherUserPhoto!)
                : null,
            backgroundColor: const Color(0xFFF3F4F6),
            child: widget.otherUserPhoto == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Color(0xFF9CA3AF),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            widget.otherUserName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Trimite primul mesaj!',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Bara de input ────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Scrie un mesaj…',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
