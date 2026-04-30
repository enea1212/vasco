import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../providers/messaging_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/user_provider.dart';
import '../repository/friends_repository.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    if (currentUser == null) return const SizedBox();

    final conversations = context.watch<MessagingProvider>().conversations;
    final friends = context.watch<FriendsProvider>().friends;

    final filtered = _query.isEmpty
        ? <UserModel>[]
        : friends
            .where((f) => (f.displayName ?? '')
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Caută prieteni…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF9CA3AF), size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 18, color: Color(0xFF9CA3AF)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(filtered, currentUser.id)
                : _buildConversationsList(conversations, currentUser.id,
                    friends),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<UserModel> results, String currentUserId) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Niciun prieten găsit.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) {
        final friend = results[i];
        return _FriendTile(friend: friend, currentUserId: currentUserId);
      },
    );
  }

  Widget _buildConversationsList(List<ConversationModel> conversations,
      String currentUserId, List<UserModel> friends) {
    if (conversations.isEmpty && friends.isEmpty) {
      return _emptyState();
    }

    return CustomScrollView(
      slivers: [
        if (conversations.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Recente',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final isLast = i == conversations.length - 1;
                return Column(
                  children: [
                    _ConvTile(
                      conv: conversations[i],
                      currentUserId: currentUserId,
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 80, endIndent: 16),
                  ],
                );
              },
              childCount: conversations.length,
            ),
          ),
        ],
        if (friends.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Toți prietenii',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final isLast = i == friends.length - 1;
                return Column(
                  children: [
                    _FriendTile(
                      friend: friends[i],
                      currentUserId: currentUserId,
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  ],
                );
              },
              childCount: friends.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nicio conversație',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Caută un prieten și trimite-i un mesaj.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Tile prieten (pentru search + lista toți) ────────────────────────────────

class _FriendTile extends StatelessWidget {
  final UserModel friend;
  final String currentUserId;

  const _FriendTile({required this.friend, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final msgProvider = context.read<MessagingProvider>();
        final convId = await msgProvider.openChat(currentUserId, friend.id);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: convId,
                currentUserId: currentUserId,
                otherUserId: friend.id,
                otherUserName: friend.displayName ?? 'Utilizator',
                otherUserPhoto: friend.photoUrl,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: friend.photoUrl != null
                  ? NetworkImage(friend.photoUrl!)
                  : null,
              backgroundColor: const Color(0xFFF3F4F6),
              child: friend.photoUrl == null
                  ? const Icon(Icons.person_rounded,
                      color: Color(0xFF9CA3AF), size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              friend.displayName ?? 'Utilizator',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile conversație recentă ─────────────────────────────────────────────────

class _ConvTile extends StatefulWidget {
  final ConversationModel conv;
  final String currentUserId;

  const _ConvTile({required this.conv, required this.currentUserId});

  @override
  State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final otherId = widget.conv.participantIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return;
    final user = await FriendsRepository().fetchUser(otherId);
    if (mounted) setState(() => _otherUser = user);
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}z';
    return '${dt.day}.${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conv;
    final unread = conv.unreadFor(widget.currentUserId);
    final otherId = conv.participantIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );
    final name = _otherUser?.displayName ?? '…';
    final photo = _otherUser?.photoUrl;

    return InkWell(
      onTap: () {
        if (otherId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conv.id,
              currentUserId: widget.currentUserId,
              otherUserId: otherId,
              otherUserName: name,
              otherUserPhoto: photo,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      photo != null ? NetworkImage(photo) : null,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: photo == null
                      ? const Icon(Icons.person_rounded,
                          color: Color(0xFF9CA3AF))
                      : null,
                ),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 15,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      Text(
                        _timeLabel(conv.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unread > 0
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF9CA3AF),
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage.isEmpty
                              ? 'Conversație nouă'
                              : conv.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
