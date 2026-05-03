import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:vasco/utils/scroll_utils.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/helpers/mapbox_helper.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/screens/profile_page.dart';
import 'package:vasco/screens/user_profile_screen.dart';
import 'package:vasco/screens/friends_page.dart';
import 'package:vasco/screens/conversations_screen.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/services/geocoding_service.dart';
import 'package:vasco/widgets/comments_sheet.dart';
import '../widget/custom_bottom_nav_bar.dart';
import 'package:vasco/screens/map_page.dart';
import 'package:vasco/services/spotify_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _FeedPage(),            // 0 - Home
      const FriendsPage(),          // 1 - Friends
      const ConversationsScreen(),  // 2 - Mesaje
      Container(),                  // 3 - Share (buton central)
      MapPage(),                    // 4 - Map
      const ProfileScreen(),        // 5 - Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: (_selectedIndex == 5 || _selectedIndex == 0) ? null : AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, color: Color(0xFF4F46E5), size: 22),
            SizedBox(width: 6),
            Text(
              'Vasco',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF374151)),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
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

  Future<void> _shareLocation(BuildContext context) async {
    final userModel = context.read<UserProvider>().user;
    if (userModel == null) return;

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
              accuracy: geo.LocationAccuracy.high));
    } catch (_) {
      return;
    }

    // 2. Alege sursa foto
    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adaugă o poză',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Alege sursa fotografiei',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _dialogOption(ctx, Icons.camera_alt_rounded, 'Cameră', 'camera')),
                  const SizedBox(width: 12),
                  Expanded(child: _dialogOption(ctx, Icons.photo_library_rounded, 'Galerie', 'gallery')),
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
    final geoJsonString = await rootBundle.loadString('assets/custom.geo.json');
    final geoJsonData = json.decode(geoJsonString) as Map<String, dynamic>;
    final detected = MapboxHelper.detectCountry(pos.latitude, pos.longitude, geoJsonData);
    final countryName = detected?['value'];

    // 4. Reverse geocoding → "Oraș, Țară"
    final locationName = await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);

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

    // 5. Actualizează lista de țări vizitate
    if (detected != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userModel.id)
          .set(
            {'shared_countries': FieldValue.arrayUnion([detected])},
            SetOptions(merge: true),
          );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detected != null
              ? 'Locație înregistrată în ${detected['value']}!'
              : 'Locație înregistrată!'),
        ),
      );
    }
  }

  Widget _dialogOption(BuildContext ctx, IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4F46E5), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ],
        ),
      ),
    );
  }

}

// ─── Feed Instagram-style ─────────────────────────────────────────────────────

class _FeedPage extends StatefulWidget {
  const _FeedPage();

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  late Stream<QuerySnapshot> _feedStream;

  @override
  void initState() {
    super.initState();
    _feedStream = _buildStream();
  }

  Stream<QuerySnapshot> _buildStream() =>
      FirebaseFirestore.instance
          .collection('location_photos')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots();

  Future<void> _onRefresh() async {
    setState(() => _feedStream = _buildStream());
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().user;
    final friends = context.watch<FriendsProvider>().friends;

    return Column(
      children: [
        // ── AppBar fix (nu se mai mișcă cu scroll-ul) ──────────────────────
        Material(
          color: Colors.white,
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
                            color: Color(0xFF111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.favorite_border_rounded,
                              color: Color(0xFF111827), size: 26),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_outlined,
                              color: Color(0xFF111827), size: 24),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: _feedStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

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
                    SliverToBoxAdapter(
                      child: _StoriesRow(currentUser: currentUser, friends: friends),
                    ),

                    const SliverToBoxAdapter(
                      child: Divider(height: 0.5, thickness: 0.5),
                    ),

                    if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4F46E5),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (docs.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.photo_camera_outlined,
                                    size: 36, color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(height: 16),
                              const Text('Nicio postare încă',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Color(0xFF374151))),
                              const SizedBox(height: 4),
                              const Text(
                                'Apasă butonul central pentru a posta.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final doc = docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            return _PostCard(docId: doc.id, data: data);
                          },
                          childCount: docs.length,
                        ),
                      ),

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

// ─── Stories row ──────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  final dynamic currentUser;
  final List friends;

  const _StoriesRow({required this.currentUser, required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        itemCount: 1 + friends.length,
        itemBuilder: (_, i) {
          if (i == 0) {
            // Story-ul utilizatorului curent
            final photo = currentUser?.photoUrl as String?;
            return _StoryItem(
              name: 'Tu',
              photoUrl: photo,
              isMe: true,
            );
          }
          final friend = friends[i - 1];
          return _StoryItem(
            name: (friend.displayName as String? ?? 'Prieten')
                .split(' ')
                .first,
            photoUrl: friend.photoUrl as String?,
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isMe;

  const _StoryItem({required this.name, this.photoUrl, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF09433), Color(0xFFE6683C),
                             Color(0xFFDC2743), Color(0xFFCC2366),
                             Color(0xFFBC1888)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl!) : null,
                    backgroundColor: const Color(0xFFF3F4F6),
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: Color(0xFF6B7280),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card individual cu geocoding lazy + cache ────────────────────────────────

class _PostCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PostCard({required this.docId, required this.data});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  static final Map<String, String> _geoCache = {};
  String? _locationLabel;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final d = widget.data;
    final stored = d['locationName'] as String? ?? d['countryName'] as String?;
    if (stored != null && stored.isNotEmpty) {
      if (mounted) setState(() => _locationLabel = stored);
      return;
    }
    final lat = (d['latitude'] as num?)?.toDouble();
    final lng = (d['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (mounted) setState(() => _locationLabel = 'Locație');
      return;
    }
    final key = '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    if (_geoCache.containsKey(key)) {
      if (mounted) setState(() => _locationLabel = _geoCache[key]);
      return;
    }
    final result = await GeocodingService.reverseGeocode(lat, lng);
    final label = result ?? 'Locație';
    _geoCache[key] = label;
    if (mounted) setState(() => _locationLabel = label);
  }

  Future<void> _toggleLike(String currentUserId) async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('toggleLike')
          .call({'postId': widget.docId, 'collection': 'location_photos'});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _openComments(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.docId,
        collection: 'location_photos',
        currentUserId: currentUserId,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLikers() async {
    final likesSnap = await FirebaseFirestore.instance
        .collection('location_photos')
        .doc(widget.docId)
        .collection('likes')
        .get();
    final result = <Map<String, dynamic>>[];
    for (final likeDoc in likesSnap.docs) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(likeDoc.id)
          .get();
      if (userSnap.exists) {
        final u = userSnap.data() as Map<String, dynamic>;
        result.add({
          'userId': likeDoc.id,
          'displayName': u['displayName'] ?? u['display_name'] ?? 'Utilizator',
          'photoUrl': u['photoUrl'] ?? u['photo_url'],
        });
      }
    }
    return result;
  }

  void _showLikers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Aprecieri',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchLikers(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final likers = snap.data ?? [];
                    if (likers.isEmpty) {
                      return const Center(
                        child: Text('Nicio apreciere încă.',
                            style: TextStyle(color: Color(0xFF9CA3AF))),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: likers.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final liker = likers[i];
                        final photo = liker['photoUrl'] as String?;
                        final name =
                            liker['displayName'] as String? ?? 'Utilizator';
                        final likerId = liker['userId'] as String? ?? '';
                        return GestureDetector(
                          onTap: likerId.isNotEmpty
                              ? () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(
                                        userId: likerId,
                                        initialDisplayName: name,
                                        initialPhotoUrl: photo,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: photo != null
                                      ? NetworkImage(photo)
                                      : null,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  child: photo == null
                                      ? const Icon(Icons.person_rounded,
                                          color: Color(0xFF9CA3AF), size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFFD1D5DB), size: 20),
                              ],
                            ),
                          ),
                        );
                      },
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

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours}h';
    if (diff.inDays < 7) return 'acum ${diff.inDays}z';
    return 'acum ${diff.inDays ~/ 7} săpt';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final imageUrl = d['imageUrl'] as String? ?? '';
    final displayName = d['displayName'] as String? ?? 'Utilizator';
    final userPhotoUrl = d['userPhotoUrl'] as String? ?? '';
    final createdAt = d['createdAt'] as Timestamp?;
    final locationLabel = _locationLabel;
    final timeLabel = _timeAgo(createdAt);
    final currentUserId = context.watch<UserProvider>().user?.id ?? '';
    final postUserId = d['userId'] as String? ?? '';
    final spotifySong = d['spotifySong'] as String?;
    final spotifyArtist = d['spotifyArtist'] as String? ?? '';
    final spotifyAlbumArt = d['spotifyAlbumArt'] as String? ?? '';

    if (currentUserId.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (postUserId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: postUserId,
                            initialDisplayName: displayName,
                            initialPhotoUrl: userPhotoUrl.isNotEmpty
                                ? userPhotoUrl
                                : null,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      // Avatar cu border gradient
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF09433), Color(0xFFDC2743),
                                     Color(0xFFBC1888)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(1.5),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundImage: userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            backgroundColor: const Color(0xFFF3F4F6),
                            child: userPhotoUrl.isEmpty
                                ? const Icon(Icons.person_rounded,
                                    color: Color(0xFF9CA3AF), size: 16)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (locationLabel != null)
                              Text(
                                locationLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.more_horiz_rounded,
                  color: Color(0xFF111827), size: 22),
            ],
          ),
        ),

        // ── Imagine full-width ─────────────────────────────────────────────
        Stack(
          children: [
            imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, e, stack) => _placeholder(),
                  )
                : _placeholder(),
            if (spotifySong != null)
              Positioned(
                bottom: 10,
                left: 10,
                right: 60,
                child: _MusicBadge(
                  songName: spotifySong,
                  artistName: spotifyArtist,
                  albumArtUrl: spotifyAlbumArt,
                ),
              ),
          ],
        ),

        // ── Acțiuni + statistici ───────────────────────────────────────────
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('location_photos')
              .doc(widget.docId)
              .collection('likes')
              .doc(currentUserId)
              .snapshots(),
          builder: (_, likeSnap) {
            final isLiked = likeSnap.data?.exists ?? false;
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('location_photos')
                  .doc(widget.docId)
                  .snapshots(),
              builder: (_, postSnap) {
                final pd =
                    postSnap.data?.data() as Map<String, dynamic>?;
                final likesCount = pd?['likesCount'] ?? 0;
                final commentsCount = pd?['commentsCount'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Butoane acțiuni
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleLike(currentUserId),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isLiked),
                                size: 28,
                                color: isLiked
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () =>
                                _openComments(context, currentUserId),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 26,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.send_outlined,
                              size: 25, color: Color(0xFF111827)),
                          const Spacer(),
                          const Icon(Icons.bookmark_border_rounded,
                              size: 26, color: Color(0xFF111827)),
                        ],
                      ),
                    ),

                    // Număr aprecieri (tap → cine a dat like)
                    if (likesCount > 0)
                      GestureDetector(
                        onTap: () => _showLikers(context),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 6, 12, 0),
                          child: Text(
                            '$likesCount aprecieri',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),

                    // Comentarii count
                    if (commentsCount > 0)
                      GestureDetector(
                        onTap: () =>
                            _openComments(context, currentUserId),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 3, 12, 0),
                          child: Text(
                            'Vizualizați toate cele $commentsCount comentarii',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),

                    // Timestamp
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const Divider(height: 0.5, thickness: 0.5),
      ],
    );
  }

  Widget _placeholder() => Container(
      height: 300,
      color: const Color(0xFFF3F4F6),
      child: const Center(
          child: Icon(Icons.image_rounded,
              size: 52, color: Color(0xFF9CA3AF))));
}

// ─── Music badge (BeReal-style Spotify) ──────────────────────────────────────

class _MusicBadge extends StatelessWidget {
  final String songName;
  final String artistName;
  final String albumArtUrl;

  const _MusicBadge({
    required this.songName,
    required this.artistName,
    required this.albumArtUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: albumArtUrl.isNotEmpty
                ? Image.network(
                    albumArtUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _albumPlaceholder(),
                  )
                : _albumPlaceholder(),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  songName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artistName.isNotEmpty)
                  Text(
                    artistName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.music_note_rounded,
              color: Color(0xFF1DB954), size: 14),
        ],
      ),
    );
  }

  Widget _albumPlaceholder() => Container(
        width: 36,
        height: 36,
        color: const Color(0xFF374151),
        child: const Icon(Icons.music_note_rounded,
            color: Color(0xFF9CA3AF), size: 18),
      );
}

