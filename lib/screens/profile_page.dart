import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/models/user_model.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/providers/photos_provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/repository/edit_profile.dart';
import 'package:vasco/screens/dating_preferences_screen.dart';
import 'package:vasco/screens/settings_page.dart';
import 'package:vasco/widgets/post_story_viewer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
@override
  void initState() {
    super.initState();
    // Declanșăm ascultarea pozelor pentru utilizatorul curent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().user?.id;
      if (userId != null) {
        context.read<PhotosProvider>().listenToUserPhotos(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, FriendsProvider, PhotosProvider>(
      builder: (context, userProvider, friendsProvider, photosProvider, _) {
        final user = userProvider.user;
        final friends = friendsProvider.friends;
        final photoDocs = photosProvider.photoDocs;
        final photosCount = photosProvider.photosCount;
        final totalLikes = photosProvider.totalLikes; // Această valoare se va updata automat

        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            // ── Header gradient ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHeader(user: user),
            ),

            // ── Stats cards 2×2 ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsGrid(
                countries: user.sharedCountriesCount,
                friends: friends.length,
                photos: photosCount,
                likes: totalLikes,
                onFriendsTap: () => _showFriendsList(context, friends),
              ),
            ),

            // ── Butoane editare ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Editează profilul'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DatingPreferencesScreen()),
                        ),
                        icon: const Icon(Icons.favorite_outline_rounded, size: 16),
                        label: const Text('Intalneste persoane noi '),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Călătoriile mele ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _TripsSection(
                photoDocs: photoDocs,
              ),
            ),

            // ── Realizări ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _AchievementsSection(
                countries: user.sharedCountriesCount,
                photos: photosCount,
                friends: friends.length,
              ),
            ),

            // Padding pentru bara de navigare
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        );
      },
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
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${friends.length}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ),
              if (friends.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Nu ai niciun prieten încă.',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: friends.length,
                    itemBuilder: (_, i) {
                      final f = friends[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  (f.photoUrl?.isNotEmpty == true)
                                      ? NetworkImage(f.photoUrl!)
                                      : null,
                              backgroundColor: const Color(0xFFE5E7EB),
                              child: (f.photoUrl?.isNotEmpty == true)
                                  ? null
                                  : const Icon(Icons.person_rounded,
                                      color: Color(0xFF9CA3AF), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                f.displayName ?? f.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
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
}

// ─── Header gradient ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = (user.displayName?.isNotEmpty == true)
        ? user.displayName!
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .take(2)
            .join()
        : 'TU';

    final username = '@${(user.displayName ?? 'username').toLowerCase().replaceAll(' ', '_')}';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Bara de sus: titlu + setări
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundImage:
                      (user.photoUrl?.isNotEmpty == true)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: (user.photoUrl == null ||
                          user.photoUrl!.isEmpty)
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Nume
            Text(
              user.displayName ?? 'Utilizator',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─── Stats 2×2 ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final int countries;
  final int friends;
  final int photos;
  final int likes;
  final VoidCallback onFriendsTap;

  const _StatsGrid({
    required this.countries,
    required this.friends,
    required this.photos,
    required this.likes,
    required this.onFriendsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.public_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  iconBg: const Color(0xFFEEF2FF),
                  value: '$countries',
                  label: 'Țări vizitate',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onFriendsTap,
                  child: _StatCard(
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF3E8FF),
                    value: '$friends',
                    label: 'Prieteni',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFD1FAE5),
                  value: '$photos',
                  label: 'Fotografii',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFEF4444),
                  iconBg: const Color(0xFFFEE2E2),
                  value: '$likes',
                  label: 'Like-uri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Secțiunea Călătoriile mele ───────────────────────────────────────────────

class _TripsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> photoDocs;

  const _TripsSection({required this.photoDocs});

  @override
  Widget build(BuildContext context) {
    if (photoDocs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Călătoriile mele', false),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 40, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 8),
                  Text(
                    'Nicio fotografie încă',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final preview = photoDocs.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Călătoriile mele', photoDocs.length > 6),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: preview.length,
            itemBuilder: (context, index) {
              final data =
                  preview[index].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] as String? ?? '';
              final location = data['locationName'] as String? ??
                  data['countryName'] as String? ?? '';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostStoryViewer(
                      docs: photoDocs.cast<QueryDocumentSnapshot>(),
                      initialIndex: index,
                      collection: 'location_photos',
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: const Color(0xFFF3F4F6)),
                      // Label locație jos
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: location.isNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.location_on_rounded,
                                        size: 9,
                                        color: Colors.white),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      BuildContext context, String title, bool showViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        if (showViewAll)
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Vezi toate',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Realizări ────────────────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final int countries;
  final int photos;
  final int friends;

  const _AchievementsSection({
    required this.countries,
    required this.photos,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    final achievements = [
      _AchievementData(
        emoji: '🌍',
        title: 'Explorator Global',
        subtitle: 'Ai vizitat 10+ țări',
        isUnlocked: countries >= 10,
        unlockedColor: const Color(0xFFFEF3C7),
      ),
      _AchievementData(
        emoji: '📷',
        title: 'Fotograf Pasionat',
        subtitle: 'Peste 100 de fotografii',
        isUnlocked: photos >= 100,
        unlockedColor: const Color(0xFFE0F2FE),
      ),
      _AchievementData(
        emoji: '🧗',
        title: 'Aventurier',
        subtitle: 'Ai vizitat 5 țări',
        isUnlocked: countries >= 5,
        unlockedColor: const Color(0xFFD1FAE5),
      ),
      _AchievementData(
        emoji: '👥',
        title: 'Conector Social',
        subtitle: '20+ prieteni',
        isUnlocked: friends >= 20,
        unlockedColor: const Color(0xFFF3E8FF),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Realizări 🏆',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ...achievements.map((a) => _AchievementTile(data: a)),
        ],
      ),
    );
  }
}

class _AchievementData {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isUnlocked;
  final Color unlockedColor;

  const _AchievementData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
    required this.unlockedColor,
  });
}

class _AchievementTile extends StatelessWidget {
  final _AchievementData data;
  const _AchievementTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: data.isUnlocked
            ? data.unlockedColor
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isUnlocked
              ? data.unlockedColor.withValues(alpha: 0.0)
              : const Color(0xFFF3F4F6),
        ),
      ),
      child: Row(
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: data.isUnlocked
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: data.isUnlocked
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            data.isUnlocked
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            color: data.isUnlocked
                ? const Color(0xFF059669)
                : const Color(0xFFD1D5DB),
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ─── Dialog edit/delete postare (folosit din exterior) ───────────────────────

void showPostOptions(
  BuildContext context,
  String postId,
  Map<String, dynamic> data,
  PostRepository postRepo,
) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: Color(0xFF4F46E5)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditDialog(
                        context, postId, data['description'], postRepo);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded,
                      color: Color(0xFFEF4444)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(
                        context, postId, data['imageUrl'], postRepo);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF9CA3AF)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.network(data['imageUrl']),
          ),
          if ((data['description'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(data['description'],
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF374151))),
            ),
        ],
      ),
    ),
  );
}

void _showEditDialog(BuildContext context, String postId,
    String? currentDesc, PostRepository postRepo) {
  final controller = TextEditingController(text: currentDesc);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Editează'),
      content: TextField(controller: controller),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează')),
        ElevatedButton(
          onPressed: () async {
            await postRepo.editPost(postId, controller.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Salvează'),
        ),
      ],
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, String postId,
    String imageUrl, PostRepository postRepo) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ștergi postarea?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nu')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white),
          onPressed: () async {
            await postRepo.deletePost(postId, imageUrl);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Șterge'),
        ),
      ],
    ),
  );
}
