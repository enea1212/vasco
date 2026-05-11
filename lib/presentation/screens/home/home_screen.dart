import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:vasco/utils/scroll_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/helpers/mapbox_helper.dart';
import 'package:vasco/models/user_model.dart';
import 'package:vasco/providers/feed_cache_provider.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/repository/messaging_repository.dart';
import 'package:vasco/screens/profile_page.dart';
import 'package:vasco/screens/conversations_screen.dart';
import 'package:vasco/screens/map_page.dart';
import 'package:vasco/screens/swipe_screen.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/services/geocoding_service.dart';
import 'package:vasco/services/spotify_service.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/presentation/screens/friends/friends_page.dart';
import 'package:vasco/presentation/widgets/custom_bottom_nav_bar.dart';
import 'widgets/post_card.dart';
import 'widgets/story_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSharingLocation = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _FeedPage(), // 0 - Home
      const FriendsPage(), // 1 - Friends
      const ConversationsScreen(), // 2 - Mesaje
      Container(), // 3 - Share (buton central)
      MapPage(), // 4 - Map
      const ProfileScreen(), // 5 - Profile
      SwipeScreen(), // Index 6
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: (_selectedIndex == 5 || _selectedIndex == 0)
          ? null
          : AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.travel_explore_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Vasco',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                if (_selectedIndex == 2)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMid,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.group_add_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        final friends = context.read<FriendsProvider>().friends;
                        _showCreateGroupDialog(context, friends);
                      },
                    ),
                  ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        isCenterActionLoading: _isSharingLocation,
        onTap: (index) {
          if (index == 3) {
            _shareLocation(context);
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Future<void> _showCreateGroupDialog(
    BuildContext context,
    List<UserModel> friends,
  ) async {
    final currentUserId = context.read<UserProvider>().user?.id ?? '';
    final nameController = TextEditingController();
    final selected = <String>{};
    var isCreating = false;
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
                const Text(
                  'Adaugă prieteni:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nu ai prieteni de adăugat.',
                      style: TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  )
                else
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
                          title: Text(
                            f.displayName ?? f.email,
                            style: const TextStyle(fontSize: 14),
                          ),
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
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      setInner(() => isCreating = true);
                      try {
                        await MessagingRepository().createGroupConversation(
                          currentUserId,
                          selected.toList(),
                          name,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Grup creat cu succes!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Eroare: $e')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setInner(() => isCreating = false);
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crează'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLocation(BuildContext context) async {
    if (_isSharingLocation) return;
    final userModel = context.read<UserProvider>().user;
    if (userModel == null) return;

    setState(() => _isSharingLocation = true);
    try {
      // 1. Permisiune locație
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activează locația în setări.')),
          );
        }
        return;
      }
      geo.LocationPermission perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
        if (perm == geo.LocationPermission.denied) return;
      }
      if (perm == geo.LocationPermission.deniedForever) return;

      geo.Position pos;
      try {
        pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
          ),
        );
      } catch (_) {
        return;
      }

      // 2. Alege sursa foto
      if (!context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.purple],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Adaugă o poză',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Alege sursa fotografiei',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _dialogOption(
                        ctx,
                        Icons.camera_alt_rounded,
                        'Cameră',
                        'camera',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogOption(
                        ctx,
                        Icons.photo_library_rounded,
                        'Galerie',
                        'gallery',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (choice == null) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile == null) return;

      SpotifyTrack? spotifyTrack;
      if (await SpotifyService.isConnected()) {
        spotifyTrack = await SpotifyService.getCurrentTrack();
      }

      // 3. Detectează țara din assets (rapid, fără rețea)
      final geoJsonString = await rootBundle.loadString(
        'assets/custom.geo.json',
      );
      final geoJsonData = json.decode(geoJsonString) as Map<String, dynamic>;
      final detected = MapboxHelper.detectCountry(
        pos.latitude,
        pos.longitude,
        geoJsonData,
      );
      final countryName = detected?['value'];

      // 4. Reverse geocoding → "Oraș, Țară"
      final locationName = await GeocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se încarcă poza...')),
        );
      }

      // 5. Upload foto cu locația completă
      await MyPhotoService.uploadPhoto(
        userId: userModel.id,
        displayName: userModel.displayName ?? 'Unknown',
        userPhotoUrl: userModel.photoUrl,
        latitude: pos.latitude,
        longitude: pos.longitude,
        imageFile: File(pickedFile.path),
        countryName: countryName,
        locationName: locationName,
        spotifySong: spotifyTrack?.songName,
        spotifyArtist: spotifyTrack?.artistName,
        spotifyAlbumArt: spotifyTrack?.albumArtUrl,
      );

      // 6. Actualizează lista de țări vizitate
      if (detected != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userModel.id)
            .set({
              'shared_countries': FieldValue.arrayUnion([detected]),
            }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detected != null
                  ? 'Locație înregistrată în ${detected['value']}!'
                  : 'Locație înregistrată!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare la postare: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingLocation = false);
    }
  }

  Widget _dialogOption(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feed Instagram-style ─────────────────────────────────────────────────────

class _FeedPage extends StatelessWidget {
  const _FeedPage();

  Future<void> _refreshFeed(BuildContext context) {
    final refresh = context.read<FeedCacheProvider>().refresh();
    return Future.any([
      refresh,
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final friends = context.watch<FriendsProvider>().friends;
    final feed = context.watch<FeedCacheProvider>();

    return Column(
      children: [
        // ── AppBar fix ────────────────────────────────────────────────────
        Material(
          color: AppColors.surface,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Text(
                          'Vasco',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            color: AppColors.textPrimary,
                            size: 26,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.send_outlined,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 0.5, thickness: 0.5),
            ],
          ),
        ),

        // ── Feed scrollabil cu pull-to-refresh ────────────────────────────
        Expanded(
          child: Builder(
            builder: (context) {
              final posts = feed.posts;
              final isInitialLoading = feed.isInitialLoading;

              return ScrollConfiguration(
                behavior: const NoGlowScrollBehavior(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () => _refreshFeed(context),
                      refreshTriggerPullDistance: 36,
                      refreshIndicatorExtent: 30,
                      builder: buildPullRefreshIndicator,
                    ),
                    SliverToBoxAdapter(
                      child: StoriesRow(
                        currentUser: currentUser,
                        friends: friends,
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: Divider(height: 0.5, thickness: 0.5),
                    ),

                    if (isInitialLoading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (posts.isEmpty)
                      SliverFillRemaining(
                        child: Center(
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
                                  Icons.photo_camera_outlined,
                                  size: 36,
                                  color: AppColors.textHint,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Nicio postare încă',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Apasă butonul central pentru a posta.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      if (feed.error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              'Se afișează cache-ul local momentan.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, i) {
                          final post = posts[i];
                          final docId = post['id'] as String? ?? '';
                          return PostCard(docId: docId, data: post);
                        }, childCount: posts.length),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
