import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'dart:async';
import 'package:vasco/core/utils/scroll_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/domain/entities/message_entity.dart';
import 'package:vasco/domain/entities/user_entity.dart';
import 'package:vasco/domain/repositories/i_user_repository.dart';
import 'package:vasco/data/datasources/remote/message_remote_datasource.dart';
import 'package:vasco/presentation/providers/domain/messaging_provider.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/core/constants/app_colors.dart';
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
        ? <UserEntity>[]
        : friends
              .where(
                (f) => (f.displayName ?? '').toLowerCase().contains(
                  _query.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search friends…',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(filtered, currentUser.id)
                : _buildConversationsList(
                    conversations,
                    currentUser.id,
                    friends,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<UserEntity> results, String currentUserId) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No friend found.',
          style: TextStyle(color: AppColors.textHint, fontSize: 14),
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

  Widget _buildConversationsList(
    List<ConversationEntity> conversations,
    String currentUserId,
    List<UserEntity> friends,
  ) {
    final validConversations = conversations.where((c) {
      final otherId = c.participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      return otherId.isNotEmpty && otherId != currentUserId;
    }).toList();

    if (validConversations.isEmpty && friends.isEmpty) {
      return _emptyState();
    }

    return ScrollConfiguration(
      behavior: const NoGlowScrollBehavior(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              final provider = context.read<MessagingProvider>();
              final oldConvs = List.of(provider.conversations);
              provider.init(currentUserId);
              final completer = Completer<void>();
              void listener() {
                if (provider.conversations != oldConvs &&
                    !completer.isCompleted) {
                  completer.complete();
                }
              }

              provider.addListener(listener);
              await Future.any(<Future<void>>[
                completer.future,
                Future.delayed(const Duration(seconds: 2)),
              ]);
              provider.removeListener(listener);
            },
            refreshTriggerPullDistance: 36,
            refreshIndicatorExtent: 30,
            builder: buildPullRefreshIndicator,
          ),
          if (validConversations.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final isLast = i == validConversations.length - 1;
                return Column(
                  children: [
                    _ConvTile(
                      conv: validConversations[i],
                      currentUserId: currentUserId,
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 80, endIndent: 16),
                  ],
                );
              }, childCount: validConversations.length),
            ),
          ],
          if (friends.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'All friends',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
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
              }, childCount: friends.length),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search a friend and send them a message.',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Tile prieten (pentru search + lista toți) ────────────────────────────────

class _FriendTile extends StatefulWidget {
  final UserEntity friend;
  final String currentUserId;

  const _FriendTile({required this.friend, required this.currentUserId});

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _openingChat = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openingChat ? null : _openChat,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: widget.friend.photoUrl != null
                  ? NetworkImage(widget.friend.photoUrl!)
                  : null,
              backgroundColor: AppColors.surfaceAlt,
              child: widget.friend.photoUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.friend.displayName ?? 'User',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (_openingChat)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final convId = await context.read<MessageRemoteDatasource>().getOrCreateConversation(
        widget.currentUserId,
        widget.friend.id,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            currentUserId: widget.currentUserId,
            otherUserId: widget.friend.id,
            otherUserName: widget.friend.displayName ?? 'User',
            otherUserPhoto: widget.friend.photoUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open chat: $e')));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }
}

// ─── Tile conversație recentă ─────────────────────────────────────────────────

class _ConvTile extends StatefulWidget {
  final ConversationEntity conv;
  final String currentUserId;

  const _ConvTile({required this.conv, required this.currentUserId});

  @override
  State<_ConvTile> createState() => _ConvTileState();
}

class _ConvTileState extends State<_ConvTile> {
  UserEntity? _otherUser;

  @override
  void initState() {
    super.initState();
    if (!widget.conv.isGroup) _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final otherId = widget.conv.participantIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return;
    final user = await context.read<IUserRepository>().getUser(otherId);
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
    final unread = conv.unreadCount[widget.currentUserId] ?? 0;

    final String name;
    final String? photo;
    final String otherId;

    if (conv.isGroup) {
      name = conv.name ?? 'Group';
      photo = null;
      otherId = '';
    } else {
      otherId = conv.participantIds.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );
      name = _otherUser?.displayName ?? '…';
      photo = _otherUser?.photoUrl;
    }

    return InkWell(
      onTap: () {
        if (!conv.isGroup && otherId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => conv.isGroup
                ? ChatScreen(
                    conversationId: conv.id,
                    currentUserId: widget.currentUserId,
                    groupName: name,
                    groupParticipantIds: conv.participantIds,
                  )
                : ChatScreen(
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
                conv.isGroup
                    ? Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMid,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      )
                    : CircleAvatar(
                        radius: 26,
                        backgroundImage: photo != null
                            ? NetworkImage(photo)
                            : null,
                        backgroundColor: AppColors.surfaceAlt,
                        child: photo == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: AppColors.textHint,
                              )
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
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _timeLabel(conv.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unread > 0
                              ? AppColors.primary
                              : AppColors.textHint,
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
                              ? 'New conversation'
                              : conv.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.textSecondary
                                : AppColors.textHint,
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
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
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
