import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:vasco/core/utils/scroll_utils.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/data/datasources/remote/message_remote_datasource.dart';
import 'package:vasco/domain/entities/user_entity.dart';
import 'package:vasco/models/user_model.dart';
import 'package:vasco/presentation/providers/domain/friends_provider.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/presentation/screens/profile/profile_page.dart';
import 'package:vasco/presentation/screens/chat/conversations_screen.dart';
import 'package:vasco/presentation/screens/map/map_page.dart';
import 'package:vasco/presentation/screens/swipe/swipe_screen.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/services/geocoding_service.dart';
import 'package:vasco/services/spotify_service.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/presentation/providers/domain/friends_feed_provider.dart';
import 'package:vasco/presentation/screens/friends/friends_page.dart';
import 'package:vasco/presentation/widgets/custom_bottom_nav_bar.dart';
import 'widgets/post_card.dart';

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
      SwipeScreen(), // 5 - Match
      const ProfileScreen(), // 6 - Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: (_selectedIndex == 6 || _selectedIndex == 0)
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
    List<UserEntity> friends,
  ) async {
    final currentUserId = context.read<UserProvider>().user?.id ?? '';
    final nameController = TextEditingController();
    final selected = <String>{};
    var isCreating = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('New Group'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add friends:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No friends to add.',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      setInner(() => isCreating = true);
                      try {
                        await context
                            .read<MessageRemoteDatasource>()
                            .createGroupConversation(
                              currentUserId,
                              selected.toList(),
                              name,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Group created successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
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
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareLocation(BuildContext context) async {
    if (_isSharingLocation) return;
    final userEntity = context.read<UserProvider>().user;
    if (userEntity == null) return;

    setState(() => _isSharingLocation = true);
    try {
      // 1. Permisiune locație
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')),
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
                  'Add a photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose photo source',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _dialogOption(
                        ctx,
                        Icons.camera_alt_rounded,
                        'Camera',
                        'camera',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogOption(
                        ctx,
                        Icons.photo_library_rounded,
                        'Gallery',
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
      // Country detection: attempt point-in-polygon lookup
      Map<String, dynamic>? detected;
      try {
        detected = _detectCountry(pos.latitude, pos.longitude, geoJsonData);
      } catch (_) {
        detected = null;
      }
      final countryName = detected?['value'] as String?;

      // 4. Reverse geocoding → "Oraș, Țară"
      final locationName = await GeocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );
      }

      // 5. Upload foto cu locația completă
      await MyPhotoService.uploadPhoto(
        userId: userEntity.id,
        displayName: userEntity.displayName ?? 'Unknown',
        userPhotoUrl: userEntity.photoUrl,
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
            .doc(userEntity.id)
            .set({
              'shared_countries': FieldValue.arrayUnion([detected]),
            }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detected != null
                  ? 'Location saved in ${detected['value']}!'
                  : 'Location saved!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingLocation = false);
    }
  }

  /// Simple GeoJSON point-in-polygon country detection.
  Map<String, dynamic>? _detectCountry(
    double lat,
    double lng,
    Map<String, dynamic> geoJson,
  ) {
    final features = geoJson['features'] as List?;
    if (features == null) return null;
    for (final feature in features) {
      final props = (feature as Map)['properties'] as Map?;
      final geometry = feature['geometry'] as Map?;
      if (props == null || geometry == null) continue;
      if (_pointInFeature(lat, lng, geometry)) {
        final name = props['name'] ?? props['NAME'] ?? props['ADMIN'];
        if (name != null) return {'value': name.toString()};
      }
    }
    return null;
  }

  bool _pointInFeature(double lat, double lng, Map geometry) {
    final type = geometry['type'] as String?;
    final coords = geometry['coordinates'];
    if (coords == null) return false;
    if (type == 'Polygon') {
      return _pointInPolygon(lat, lng, coords[0] as List);
    } else if (type == 'MultiPolygon') {
      for (final poly in coords as List) {
        if (_pointInPolygon(lat, lng, (poly as List)[0] as List)) return true;
      }
    }
    return false;
  }

  bool _pointInPolygon(double lat, double lng, List ring) {
    bool inside = false;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; j = i++) {
      final xi = (ring[i] as List)[0] as num;
      final yi = (ring[i] as List)[1] as num;
      final xj = (ring[j] as List)[0] as num;
      final yj = (ring[j] as List)[1] as num;
      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
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

// ─── Feed cu două tab-uri: Friends / Friends of Friends ──────────────────────

class _FeedPage extends StatefulWidget {
  const _FeedPage();

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<String>? _lastFriendIds;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FriendsProvider>().addListener(_onFriendsChanged);
      // Handle case where FriendsProvider already has data (e.g. returning to tab)
      _onFriendsChanged();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    try {
      context.read<FriendsProvider>().removeListener(_onFriendsChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onFriendsChanged() {
    if (!mounted) return;
    final fp = context.read<FriendsProvider>();
    // Wait until FriendsProvider has received the first Firestore batch
    if (!fp.initialLoadComplete) return;
    final ids = fp.friends.map((f) => f.id).toList();
    if (listEquals(_lastFriendIds, ids)) return;
    _lastFriendIds = ids;
    _initFeeds();
  }

  Future<void> _initFeeds() async {
    if (!mounted) return;
    final userId = context.read<UserProvider>().user?.id;
    if (userId == null) return;
    final friendIds = _lastFriendIds ?? [];
    await context.read<FriendsFeedProvider>().initForUser(userId, friendIds);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final friendsProvider = context.watch<FriendsProvider>();
    final friendsReady = friendsProvider.initialLoadComplete;
    final feed = context.watch<FriendsFeedProvider>();

    final currentUserModel = currentUser == null
        ? null
        : UserModel(
            id: currentUser.id,
            email: currentUser.email,
            displayName: currentUser.displayName,
            photoUrl: currentUser.photoUrl,
          );

    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────────
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
                          icon: const Icon(Icons.favorite_border_rounded,
                              color: AppColors.textPrimary, size: 26),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_outlined,
                              color: AppColors.textPrimary, size: 24),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Friends of Friends'),
                ],
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
              ),
              const Divider(height: 0.5, thickness: 0.5),
            ],
          ),
        ),

        // ── Tab content ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PostsFeed(
                posts: feed.friendsFeed,
                isLoading: !friendsReady || feed.friendsLoading,
                currentUserModel: currentUserModel,
                onRefresh: _initFeeds,
                emptyTitle: 'No posts from friends',
                emptySubtitle: 'When your friends post, they\'ll appear here.',
              ),
              _PostsFeed(
                posts: feed.fofFeed,
                isLoading: !friendsReady || feed.fofLoading,
                currentUserModel: currentUserModel,
                onRefresh: _initFeeds,
                emptyTitle: 'No posts yet',
                emptySubtitle:
                    'Posts from people your friends know will appear here.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared post list widget ─────────────────────────────────────────────────

class _PostsFeed extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final UserModel? currentUserModel;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptySubtitle;

  const _PostsFeed({
    required this.posts,
    required this.isLoading,
    required this.currentUserModel,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      );
    }

    return ScrollConfiguration(
      behavior: const NoGlowScrollBehavior(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            refreshTriggerPullDistance: 36,
            refreshIndicatorExtent: 30,
            builder: buildPullRefreshIndicator,
          ),
          if (posts.isEmpty)
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
                      child: const Icon(Icons.photo_camera_outlined,
                          size: 36, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      emptyTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final data = posts[i];
                  final docId = data['id'] as String? ?? '';
                  return PostCard(
                    key: ValueKey(docId),
                    docId: docId,
                    data: data,
                    currentUserId: currentUserModel?.id ?? '',
                  );
                },
                childCount: posts.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
