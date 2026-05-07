import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/models/user_model.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/repository/friends_repository.dart';
import 'package:vasco/services/location_groups_service.dart';

class LocationGroupsScreen extends StatefulWidget {
  final String currentVisibility;

  const LocationGroupsScreen({super.key, required this.currentVisibility});

  @override
  State<LocationGroupsScreen> createState() => _LocationGroupsScreenState();
}

class _LocationGroupsScreenState extends State<LocationGroupsScreen> {
  late String _activeVisibility;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activeVisibility = widget.currentVisibility;
  }

  String? get _userId =>
      Provider.of<UserProvider>(context, listen: false).user?.id;

  Future<void> _setVisibility(String visibility) async {
    final uid = _userId;
    if (uid == null) return;
    setState(() {
      _activeVisibility = visibility;
      _saving = true;
    });
    try {
      await LocationGroupsService.setVisibility(uid, visibility);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCreateGroupDialog(List<UserModel> friends) async {
    final nameController = TextEditingController();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Grup nou'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nume grup',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                const Text('Adaugă prieteni:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    itemBuilder: (_, i) {
                      final f = friends[i];
                      final isSelected = selected.contains(f.id);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(f.displayName ?? f.email,
                            style: const TextStyle(fontSize: 14)),
                        value: isSelected,
                        onChanged: (_) => setInner(() {
                          if (isSelected) {
                            selected.remove(f.id);
                          } else {
                            selected.add(f.id);
                          }
                        }),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundImage: f.photoUrl != null
                              ? NetworkImage(f.photoUrl!)
                              : null,
                          child: f.photoUrl == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await LocationGroupsService.createGroup(
                      name, selected.toList());
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Eroare: $e')),
                  );
                }
              },
              child: const Text('Crează'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(String groupId, String groupName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Șterge grup'),
        content: Text('Ești sigur că vrei să ștergi grupul "$groupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await LocationGroupsService.deleteGroup(groupId);
      if (_activeVisibility == groupId) {
        await _setVisibility('all');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vizibilitate locație'),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: uid == null
          ? const SizedBox()
          : _Body(
              userId: uid,
              activeVisibility: _activeVisibility,
              onVisibilityChanged: _setVisibility,
              onDeleteGroup: _deleteGroup,
              onCreateGroup: _showCreateGroupDialog,
            ),
      floatingActionButton: uid == null
          ? null
          : _FriendsFab(
              userId: uid,
              onFriendsFetched: _showCreateGroupDialog,
            ),
    );
  }
}

class _Body extends StatelessWidget {
  final String userId;
  final String activeVisibility;
  final void Function(String) onVisibilityChanged;
  final void Function(String, String) onDeleteGroup;
  final void Function(List<UserModel>) onCreateGroup;

  const _Body({
    required this.userId,
    required this.activeVisibility,
    required this.onVisibilityChanged,
    required this.onDeleteGroup,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocationGroup>>(
      stream: LocationGroupsService.watchGroups(userId),
      builder: (context, snap) {
        final groups = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionHeader('Cu cine îți partajezi locația'),
            _VisibilityTile(
              label: 'Toți prietenii',
              subtitle: 'Toți prietenii tăi îți pot vedea locația',
              icon: Icons.people_rounded,
              selected: activeVisibility == 'all',
              onTap: () => onVisibilityChanged('all'),
            ),
            const Divider(indent: 16, endIndent: 16),
            _SectionHeader('Grupuri personale'),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Text(
                  'Niciun grup creat. Apasă + pentru a crea unul.',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            ...groups.map((g) => _GroupTile(
                  group: g,
                  selected: activeVisibility == g.id,
                  onTap: () => onVisibilityChanged(g.id),
                  onDelete: () => onDeleteGroup(g.id, g.name),
                )),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: selected
            ? const Color(0xFF4F46E5)
            : Colors.grey.shade200,
        child: Icon(icon,
            color: selected ? Colors.white : Colors.grey.shade500,
            size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4F46E5))
          : null,
      onTap: onTap,
    );
  }
}

class _GroupTile extends StatelessWidget {
  final LocationGroup group;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: selected
            ? const Color(0xFF4F46E5)
            : Colors.grey.shade200,
        child: Icon(Icons.group_rounded,
            color: selected ? Colors.white : Colors.grey.shade500,
            size: 20),
      ),
      title: Text(group.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${group.memberIds.length} '
        '${group.memberIds.length == 1 ? 'prieten' : 'prieteni'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4F46E5)),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FriendsFab extends StatelessWidget {
  final String userId;
  final void Function(List<UserModel>) onFriendsFetched;

  const _FriendsFab(
      {required this.userId, required this.onFriendsFetched});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF4F46E5),
      foregroundColor: Colors.white,
      onPressed: () async {
        final friends = await FriendsRepository()
            .getFriends(userId)
            .first;
        if (!context.mounted) return;
        onFriendsFetched(friends);
      },
      child: const Icon(Icons.add),
    );
  }
}
