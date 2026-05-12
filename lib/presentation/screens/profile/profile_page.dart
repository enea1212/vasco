import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/data/datasources/remote/post_remote_datasource.dart';
import 'package:vasco/domain/entities/user_entity.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/presentation/screens/map/map_page.dart';
import 'package:vasco/core/utils/scroll_utils.dart';
import 'package:vasco/presentation/widgets/story_viewer.dart';
import 'package:vasco/presentation/screens/profile/edit_profile_screen.dart';
import 'package:vasco/presentation/screens/profile/dating_preferences_screen.dart';
import 'package:vasco/presentation/screens/profile/widgets/profile_header.dart';
import 'package:vasco/presentation/screens/profile/widgets/profile_stats_grid.dart';
import 'package:vasco/presentation/screens/profile/widgets/spotify_card.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  const ProfileScreen({super.key, this.showBackButton = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Stream<QuerySnapshot>? _photosStream;
  String? _streamUid;
  UserProvider? _userProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      _initStream(userProvider.user?.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.read<UserProvider>();
    if (_userProvider == userProvider) return;
    _userProvider?.removeListener(_onUserChanged);
    _userProvider = userProvider;
    _userProvider?.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    if (!mounted) return;
    _initStream(context.read<UserProvider>().user?.id);
  }

  void _initStream(String? uid) {
    debugPrint(
      '[ProfileScreen] _initStream called with uid: $uid, _streamUid: $_streamUid',
    );
    if (uid == null || uid == _streamUid) return;
    setState(() {
      _streamUid = uid;
      _photosStream = FirebaseFirestore.instance
          .collection('location_photos')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
      debugPrint('[ProfileScreen] _photosStream set for uid: $uid');
    });
  }

  @override
  void dispose() {
    _userProvider?.removeListener(_onUserChanged);
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_streamUid != null) {
      setState(() {
        _photosStream = FirebaseFirestore.instance
            .collection('location_photos')
            .where('userId', isEqualTo: _streamUid)
            .orderBy('createdAt', descending: true)
            .snapshots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final friends = context.watch<FriendsProvider>().friends;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _photosStream,
        builder: (context, photosSnap) {
          final photoDocs = photosSnap.data?.docs ?? [];
          final photosCount = photoDocs.length;

          return ScrollConfiguration(
            behavior: const NoGlowScrollBehavior(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
                  refreshTriggerPullDistance: 36,
                  refreshIndicatorExtent: 30,
                  builder: buildPullRefreshIndicator,
                ),

                // ── Header gradient ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: ProfileHeader(
                    user: user,
                    showBackButton: widget.showBackButton,
                  ),
                ),

                // ── Stats cards 2×2 ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: ProfileStatsGrid(
                    countries: user.sharedCountriesCount,
                    friends: friends.length,
                    photos: photosCount,
                    onCountriesTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPage(userId: user.id),
                      ),
                    ),
                    onFriendsTap: () => _showFriendsList(context, friends),
                  ),
                ),

                // ── Edit buttons ─────────────────────────────────────────────
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
                                builder: (_) => const EditProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Edit profile'),
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
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DatingPreferencesScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Meet new people'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.rose,
                              side: const BorderSide(
                                color: AppColors.rosePinkLight,
                                width: 1.5,
                              ),
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
                ),

                // ── Spotify ──────────────────────────────────────────────────
                const SliverToBoxAdapter(child: SpotifyCard()),

                // ── Trips section ────────────────────────────────────────────
                SliverToBoxAdapter(child: _TripsSection(photoDocs: photoDocs)),

                // ── Achievements ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _AchievementsSection(
                    countries: user.sharedCountriesCount,
                    photos: photosCount,
                    friends: friends.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFriendsList(BuildContext context, List<UserEntity> friends) {
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
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    const Text(
                      'Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${friends.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (friends.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No friends yet.',
                      style: TextStyle(color: AppColors.textHint),
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
                      final f = friends[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
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
                              backgroundColor: AppColors.border,
                              child: (f.photoUrl?.isNotEmpty == true)
                                  ? null
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.textHint,
                                      size: 22,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                f.displayName ?? f.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
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

// ─── Trips section (grouped by country) ──────────────────────────────────────

class _TripsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> photoDocs;

  const _TripsSection({required this.photoDocs});

  Map<String, List<QueryDocumentSnapshot>> _groupByCountry() {
    final map = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in photoDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final country = data['countryName'] as String? ?? 'Other';
      map.putIfAbsent(country, () => []).add(doc);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Trips',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (photoDocs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 40,
                    color: AppColors.divider,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No photos yet',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ],
              ),
            )
          else
            ..._groupByCountry().entries.map(
              (entry) => _CountryPhotoRow(
                country: entry.key,
                docs: entry.value,
                allDocs: photoDocs,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountryPhotoRow extends StatelessWidget {
  final String country;
  final List<QueryDocumentSnapshot> docs;
  final List<QueryDocumentSnapshot> allDocs;

  const _CountryPhotoRow({
    required this.country,
    required this.docs,
    required this.allDocs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                country,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${docs.length} ${docs.length == 1 ? 'photo' : 'photos'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] as String? ?? '';
                final globalIndex = allDocs.indexOf(docs[i]);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewer(
                        photos: allDocs
                            .map((d) => {
                                  'id': d.id,
                                  ...(d.data() as Map<String, dynamic>),
                                })
                            .toList(),
                        initialIndex: globalIndex >= 0 ? globalIndex : 0,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: AppColors.surfaceAlt),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Achievements ─────────────────────────────────────────────────────────────

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
        title: 'Global Explorer',
        subtitle: 'Visited 10+ countries',
        isUnlocked: countries >= 10,
        unlockedColor: AppColors.amberLight,
      ),
      _AchievementData(
        emoji: '📷',
        title: 'Passionate Photographer',
        subtitle: 'Over 100 photos',
        isUnlocked: photos >= 100,
        unlockedColor: AppColors.skyLight,
      ),
      _AchievementData(
        emoji: '🧗',
        title: 'Adventurer',
        subtitle: 'Visited 5 countries',
        isUnlocked: countries >= 5,
        unlockedColor: AppColors.greenLight,
      ),
      _AchievementData(
        emoji: '👥',
        title: 'Social Connector',
        subtitle: '20+ friends',
        isUnlocked: friends >= 20,
        unlockedColor: AppColors.purpleLight,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements 🏆',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
        color: data.isUnlocked ? data.unlockedColor : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isUnlocked
              ? data.unlockedColor.withValues(alpha: 0.0)
              : AppColors.surfaceAlt,
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
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: data.isUnlocked
                        ? AppColors.textMuted
                        : AppColors.divider,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            data.isUnlocked
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            color: data.isUnlocked ? AppColors.greenEmerald : AppColors.divider,
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ─── Post options dialog (public helper) ─────────────────────────────────────

void showPostOptions(
  BuildContext context,
  String postId,
  Map<String, dynamic> data,
  PostRemoteDatasource postDatasource,
) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
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
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditDialog(
                      context,
                      postId,
                      data['description'],
                      postDatasource,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.danger,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(
                      context,
                      postId,
                      data['imageUrl'],
                      postDatasource,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textHint,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: Image.network(data['imageUrl']),
          ),
          if ((data['description'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                data['description'],
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

void _showEditDialog(
  BuildContext context,
  String postId,
  String? currentDesc,
  PostRemoteDatasource postDatasource,
) {
  final controller = TextEditingController(text: currentDesc);
  var isSaving = false;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      await postDatasource.editPost(
                        postId,
                        {'description': controller.text},
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                        setDialogState(() => isSaving = false);
                      }
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void _showDeleteConfirmation(
  BuildContext context,
  String postId,
  String imageUrl,
  PostRemoteDatasource postDatasource,
) {
  var isDeleting = false;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete post?'),
        actions: [
          TextButton(
            onPressed: isDeleting ? null : () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.surface,
            ),
            onPressed: isDeleting
                ? null
                : () async {
                    setDialogState(() => isDeleting = true);
                    try {
                      await postDatasource.deletePost(postId);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                        setDialogState(() => isDeleting = false);
                      }
                    }
                  },
            child: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.surface,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Delete'),
          ),
        ],
      ),
    ),
  );
}
