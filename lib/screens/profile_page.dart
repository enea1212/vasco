import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/models/user_model.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/repository/edit_profile.dart';
import 'package:vasco/screens/settings_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final postRepo = context.read<PostRepository>();
    final user = context.watch<UserProvider>().user;
    final friends = context.watch<FriendsProvider>().friends;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.displayName ?? 'Profil',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded, size: 20, color: Color(0xFF374151)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
        ),

        // ── Avatar + Stats ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    backgroundColor: const Color(0xFFF3F4F6),
                    child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                        ? const Icon(Icons.person_rounded, size: 40, color: Color(0xFF9CA3AF))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('userId', isEqualTo: user.id)
                          .snapshots(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return _statColumn('Postări', '$count');
                      },
                    ),
                    GestureDetector(
                      onTap: () => _showFriendsList(context, friends),
                      child: _statColumn('Prieteni', '${friends.length}', tappable: true),
                    ),
                    _statColumn('Țări', '${user.sharedCountriesCount}'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Nume, bio, email ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? 'Utilizator',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              if (user.biography?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  user.biography!,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Buton editare ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Editează profilul'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // ── Header postări ───────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Row(
            children: [
              Icon(Icons.grid_on_rounded, size: 18, color: Color(0xFF111827)),
              SizedBox(width: 8),
              Text(
                'Postările mele',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // ── Grid postări ─────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: user.id)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Eroare la încărcare'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
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
                        child: const Icon(Icons.photo_library_outlined, size: 36, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nicio postare',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Postările tale vor apărea aici.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(3),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showImageDialog(context, docId, data, postRepo),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(data['imageUrl'], fit: BoxFit.cover),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String count, {bool tappable = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            if (tappable) ...[
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF9CA3AF)),
            ],
          ],
        ),
      ],
    );
  }

  void _showFriendsList(BuildContext context, List<UserModel> friends) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    const Text(
                      'Prieteni',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${friends.length}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ),
              if (friends.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Nu ai niciun prieten încă.',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: friends.length,
                    itemBuilder: (_, i) {
                      final friend = friends[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: (friend.photoUrl?.isNotEmpty == true)
                                  ? NetworkImage(friend.photoUrl!)
                                  : null,
                              backgroundColor: const Color(0xFFE5E7EB),
                              child: (friend.photoUrl?.isNotEmpty == true)
                                  ? null
                                  : const Icon(Icons.person_rounded, color: Color(0xFF9CA3AF), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    friend.displayName ?? friend.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  if (friend.biography?.isNotEmpty == true)
                                    Text(
                                      friend.biography!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String postId, Map<String, dynamic> data, PostRepository postRepo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF4F46E5)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(context, postId, data['description'], postRepo);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(context, postId, data['imageUrl'], postRepo);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Image.network(data['imageUrl']),
            ),
            if (data['description'] != null && (data['description'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(data['description'], style: const TextStyle(fontSize: 15, color: Color(0xFF374151))),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String postId, String? currentDesc, PostRepository postRepo) {
    final controller = TextEditingController(text: currentDesc);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editează'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
          ElevatedButton(
            onPressed: () async {
              await postRepo.editPost(postId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String postId, String imageUrl, PostRepository postRepo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ștergi postarea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nu')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              await postRepo.deletePost(postId, imageUrl);
              Navigator.pop(context);
            },
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
  }
}
