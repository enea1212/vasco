import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../providers/friends_provider.dart';
import '../providers/user_provider.dart';
import '../repository/friends_repository.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProvider>().user;
    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    final pendingCount = context.watch<FriendsProvider>().pendingCount;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: [
            const Tab(icon: Icon(Icons.search), text: 'Caută'),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(height: 2),
                      Text('Cereri', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.people), text: 'Prieteni'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SearchTab(currentUser: currentUser),
              _RequestsTab(currentUser: currentUser),
              _FriendsTab(currentUser: currentUser),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tab Căutare ─────────────────────────────────────────────────────────────

class _SearchTab extends StatefulWidget {
  final UserModel currentUser;
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
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Caută după nume...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        context.read<FriendsProvider>().clearSearch();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (val) {
              setState(() {});
              context.read<FriendsProvider>().search(val, widget.currentUser.id);
            },
          ),
        ),
        if (provider.isSearching)
          const LinearProgressIndicator()
        else if (provider.searchQuery.isNotEmpty && provider.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Niciun utilizator găsit.', style: TextStyle(color: Colors.grey)),
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
  final UserModel user;
  final String currentUserId;
  const _UserTile({required this.user, required this.currentUserId});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  String _status = 'loading';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final s = await context.read<FriendsProvider>().getStatus(widget.currentUserId, widget.user.id);
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (widget.user.photoUrl?.isNotEmpty == true)
            ? NetworkImage(widget.user.photoUrl!)
            : null,
        child: (widget.user.photoUrl?.isNotEmpty == true) ? null : const Icon(Icons.person),
      ),
      title: Text(widget.user.displayName ?? widget.user.email),
      subtitle: widget.user.biography?.isNotEmpty == true
          ? Text(widget.user.biography!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (_status == 'loading') {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }

    final provider = context.read<FriendsProvider>();

    switch (_status) {
      case 'friends':
        return OutlinedButton(
          onPressed: () async {
            await provider.removeFriend(widget.currentUserId, widget.user.id);
            if (mounted) setState(() => _status = 'none');
          },
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Elimină'),
        );
      case 'pending_sent':
        return OutlinedButton(
          onPressed: () async {
            await provider.cancelRequest(widget.currentUserId, widget.user.id);
            if (mounted) setState(() => _status = 'none');
          },
          child: const Text('Anulează'),
        );
      case 'pending_received':
        return ElevatedButton(
          onPressed: () async {
            final req = provider.incomingRequests
                .where((r) => r.fromUserId == widget.user.id)
                .firstOrNull;
            if (req != null) {
              await provider.acceptRequest(req.id, req.fromUserId, req.toUserId);
              if (mounted) setState(() => _status = 'friends');
            }
          },
          child: const Text('Acceptă'),
        );
      default:
        return ElevatedButton.icon(
          onPressed: () async {
            await provider.sendRequest(widget.currentUserId, widget.user.id);
            if (mounted) setState(() => _status = 'pending_sent');
          },
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Adaugă'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
        );
    }
  }
}

// ─── Tab Cereri primite ───────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final UserModel currentUser;
  const _RequestsTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<FriendsProvider>().incomingRequests;

    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Nicio cerere de prietenie.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, i) => _RequestTile(
        request: requests[i],
        currentUserId: currentUser.id,
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final FriendRequestModel request;
  final String currentUserId;
  const _RequestTile({required this.request, required this.currentUserId});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  UserModel? _sender;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSender();
  }

  Future<void> _loadSender() async {
    final user = await FriendsRepository().fetchUser(widget.request.fromUserId);
    if (mounted) setState(() { _sender = user; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FriendsProvider>();
    final name = _loading ? 'Se încarcă...' : (_sender?.displayName ?? _sender?.email ?? widget.request.fromUserId);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (_sender?.photoUrl?.isNotEmpty == true)
            ? NetworkImage(_sender!.photoUrl!)
            : null,
        child: (_sender?.photoUrl?.isNotEmpty == true) ? null : const Icon(Icons.person),
      ),
      title: Text(name),
      subtitle: const Text('Vrea să fii prieten cu tine'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              await provider.acceptRequest(
                widget.request.id,
                widget.request.fromUserId,
                widget.request.toUserId,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Acceptă'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              await provider.declineRequest(widget.request.id, widget.request.fromUserId);
            },
            child: const Text('Refuză'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Lista prieteni ───────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  final UserModel currentUser;
  const _FriendsTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendsProvider>().friends;

    if (friends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Nu ai niciun prieten încă.\nCaută utilizatori pentru a adăuga prieteni.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final friend = friends[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (friend.photoUrl?.isNotEmpty == true)
                ? NetworkImage(friend.photoUrl!)
                : null,
            child: (friend.photoUrl?.isNotEmpty == true) ? null : const Icon(Icons.person),
          ),
          title: Text(friend.displayName ?? friend.email),
          subtitle: friend.biography?.isNotEmpty == true
              ? Text(friend.biography!, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'remove') {
                final confirm = await _confirmRemove(context, friend.displayName ?? friend.email);
                if (confirm && context.mounted) {
                  await context.read<FriendsProvider>().removeFriend(currentUser.id, friend.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Elimină prieten')),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmRemove(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Elimini prieten?'),
            content: Text('Ești sigur că vrei să elimini pe $name din lista de prieteni?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nu')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Elimină'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
