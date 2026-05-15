import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/domain/entities/friend_request_entity.dart';
import 'package:vasco/domain/entities/post_entity.dart';
import 'package:vasco/domain/entities/user_entity.dart';
import 'package:vasco/domain/repositories/i_user_repository.dart';
import 'package:vasco/presentation/providers/domain/coauthoring_provider.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/presentation/screens/profile/user_profile_screen.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/core/constants/app_sizes.dart';
import 'widgets/friend_tile.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingCount = context.watch<FriendsProvider>().pendingCount;
    final taggedCount = context.watch<CoAuthoringProvider>().pendingCount;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textMuted,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusTile),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              const Tab(
                icon: Icon(Icons.search_rounded, size: 20),
                text: 'Search',
              ),
              Tab(
                iconMargin: EdgeInsets.zero,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.person_add_rounded, size: 20),
                    if (pendingCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints:
                              const BoxConstraints(minWidth: 14, minHeight: 14),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$pendingCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                text: 'Requests',
              ),
              const Tab(
                icon: Icon(Icons.people_rounded, size: 20),
                text: 'Friends',
              ),
              Tab(
                iconMargin: EdgeInsets.zero,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.bookmark_add_rounded, size: 20),
                    if (taggedCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints:
                              const BoxConstraints(minWidth: 14, minHeight: 14),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$taggedCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                text: 'Tagged',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SearchTab(currentUser: currentUser),
              _RequestsTab(currentUser: currentUser),
              _FriendsTab(currentUser: currentUser),
              const _TaggedTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tab Căutare ─────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  final UserEntity currentUser;
  const _SearchTab({required this.currentUser});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
              ),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textHint,
                      ),
                      onPressed: () {
                        _ctrl.clear();
                        context.read<FriendsProvider>().clearSearch();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (val) {
              setState(() {});
              context.read<FriendsProvider>().search(
                val,
                widget.currentUser.id,
              );
            },
          ),
        ),
        if (provider.isSearching)
          const LinearProgressIndicator()
        else if (_ctrl.text.isNotEmpty && provider.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No user found.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: provider.searchResults.length,
              itemBuilder: (context, i) => _UserTile(
                user: provider.searchResults[i],
                currentUserId: widget.currentUser.id,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tile cu buton de acțiune pentru un utilizator din căutare ───────────────

class _UserTile extends StatefulWidget {
  final UserEntity user;
  final String currentUserId;
  const _UserTile({required this.user, required this.currentUserId});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  String _status = 'loading';
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final s = await context.read<FriendsProvider>().getStatus(
      widget.currentUserId,
      widget.user.id,
    );
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: widget.user.id,
            initialDisplayName: widget.user.displayName,
            initialPhotoUrl: widget.user.photoUrl,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: AppSizes.shadowBlurLg,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: (widget.user.photoUrl?.isNotEmpty == true)
                  ? NetworkImage(widget.user.photoUrl!)
                  : null,
              backgroundColor: AppColors.surfaceAlt,
              child: (widget.user.photoUrl?.isNotEmpty == true)
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      color: AppColors.textHint,
                    ),
            ),
            const SizedBox(width: AppSizes.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName ?? widget.user.email,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.user.biography?.isNotEmpty == true)
                    Text(
                      widget.user.biography!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacingMd - 6),
            _buildButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (_status == 'loading' || _actionLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final provider = context.read<FriendsProvider>();

    switch (_status) {
      case 'friends':
        return _actionBtn(
          'Friend',
          AppColors.surfaceAlt,
          AppColors.textSecondary,
          () {
            _runFriendAction(
              nextStatus: 'none',
              action: () =>
                  provider.removeFriend(widget.currentUserId, widget.user.id),
            );
          },
        );
      case 'pending_sent':
        return _actionBtn(
          'Sent',
          AppColors.surfaceAlt,
          AppColors.textMuted,
          () {
            _runFriendAction(
              nextStatus: 'none',
              action: () =>
                  provider.cancelRequest(widget.currentUserId, widget.user.id),
            );
          },
        );
      case 'pending_received':
        return _actionBtn(
          'Accept',
          AppColors.primary,
          Colors.white,
          () {
            final req = provider.incomingRequests
                .where((r) => r.fromUserId == widget.user.id)
                .firstOrNull;
            if (req != null) {
              _runFriendAction(
                nextStatus: 'friends',
                action: () =>
                    provider.acceptRequest(req.id, req.fromUserId, req.toUserId),
              );
            }
          },
        );
      default:
        return _actionBtn(
          '+ Add',
          AppColors.primary,
          Colors.white,
          () {
            _runFriendAction(
              nextStatus: 'pending_sent',
              action: () =>
                  provider.sendRequest(widget.currentUserId, widget.user.id),
            );
          },
        );
    }
  }

  Future<void> _runFriendAction({
    required String nextStatus,
    required Future<void> Function() action,
  }) async {
    if (_actionLoading) return;
    final previousStatus = _status;
    setState(() {
      _status = nextStatus;
      _actionLoading = true;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = previousStatus);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _actionBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusButton),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Tab Cereri primite ───────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final UserEntity currentUser;
  const _RequestsTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<FriendsProvider>().incomingRequests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_add_disabled_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No requests',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No pending friend requests.',
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FriendsProvider>().init(currentUser.id);
        await Future.delayed(const Duration(milliseconds: 400));
      },
      color: AppColors.primary,
      displacement: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        itemCount: requests.length,
        itemBuilder: (context, i) =>
            _RequestTile(request: requests[i], currentUserId: currentUser.id),
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final FriendRequestEntity request;
  final String currentUserId;
  const _RequestTile({required this.request, required this.currentUserId});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  UserEntity? _sender;
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSender();
  }

  Future<void> _loadSender() async {
    final entity =
        await context.read<IUserRepository>().getUser(widget.request.fromUserId);
    if (mounted) {
      setState(() {
        _sender = entity;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FriendsProvider>();
    final name = _loading
        ? 'Loading...'
        : (_sender?.displayName ?? _sender?.email ?? widget.request.fromUserId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: AppSizes.shadowBlurLg,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: (_sender?.photoUrl?.isNotEmpty == true)
                ? NetworkImage(_sender!.photoUrl!)
                : null,
            backgroundColor: AppColors.surfaceAlt,
            child: (_sender?.photoUrl?.isNotEmpty == true)
                ? null
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.textHint,
                  ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Wants to be friends',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd - 6),
          _actionLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _runRequestAction(
                          () => provider.acceptRequest(
                            widget.request.id,
                            widget.request.fromUserId,
                            widget.request.toUserId,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusIcon),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        await _runRequestAction(
                          () => provider.declineRequest(widget.request.id),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusIcon),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _runRequestAction(Future<void> Function() action) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }
}

// ─── Tab Lista prieteni ───────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  final UserEntity currentUser;
  const _FriendsTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendsProvider>().friends;

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No friends',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search for users to add\nnew friends.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FriendsProvider>().init(currentUser.id);
        await Future.delayed(const Duration(milliseconds: 400));
      },
      color: AppColors.primary,
      displacement: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        itemCount: friends.length,
        itemBuilder: (context, i) {
          final friend = friends[i];
          return FriendTile(
            name: friend.displayName ?? friend.email,
            photoUrl: friend.photoUrl,
            biography: friend.biography,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: friend.id,
                  initialDisplayName: friend.displayName,
                  initialPhotoUrl: friend.photoUrl,
                ),
              ),
            ),
            onRemove: () async {
              final confirm = await _confirmRemove(
                context,
                friend.displayName ?? friend.email,
              );
              if (confirm && context.mounted) {
                await context.read<FriendsProvider>().removeFriend(
                  currentUser.id,
                  friend.id,
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove friend?'),
            content: Text(
              'Are you sure you want to remove $name from your friends?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ─── Tab Tagged (co-author requests) ─────────────────────────────────────────

class _TaggedTab extends StatelessWidget {
  const _TaggedTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoAuthoringProvider>();
    final pending = provider.pending;

    if (provider.isLoading && pending.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 36,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tagged posts',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'When friends tag you on a post, it shows up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
      itemCount: pending.length,
      itemBuilder: (_, i) => _TaggedRequestTile(post: pending[i]),
    );
  }
}

class _TaggedRequestTile extends StatefulWidget {
  final PostEntity post;
  const _TaggedRequestTile({required this.post});

  @override
  State<_TaggedRequestTile> createState() => _TaggedRequestTileState();
}

class _TaggedRequestTileState extends State<_TaggedRequestTile> {
  UserEntity? _author;
  bool _loadingAuthor = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthor();
  }

  Future<void> _loadAuthor() async {
    final entity =
        await context.read<IUserRepository>().getUser(widget.post.userId);
    if (mounted) {
      setState(() {
        _author = entity;
        _loadingAuthor = false;
      });
    }
  }

  Future<void> _accept() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await context.read<CoAuthoringProvider>().accept(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to your profile.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept. Try again.')),
        );
      }
    }
  }

  Future<void> _decline() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await context.read<CoAuthoringProvider>().decline(widget.post.id);
    } catch (_) {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decline. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _loadingAuthor
        ? 'Loading...'
        : (_author?.displayName ?? _author?.email ?? 'A friend');
    final photo = _author?.photoUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: AppSizes.shadowBlurLg,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (author)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _author == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: widget.post.userId,
                                initialDisplayName: _author?.displayName,
                                initialPhotoUrl: _author?.photoUrl,
                              ),
                            ),
                          ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: (photo?.isNotEmpty == true)
                        ? NetworkImage(photo!)
                        : null,
                    backgroundColor: AppColors.surfaceAlt,
                    child: (photo?.isNotEmpty == true)
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.textHint,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'tagged you as co-author',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Image preview
          if (widget.post.imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppColors.surfaceAlt),
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceAlt,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading ? null : _decline,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _accept,
                    icon: _actionLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
