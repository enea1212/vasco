import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/helpers/mapbox_helper.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/screens/profile_page.dart';
import 'package:vasco/screens/friends_page.dart';
import 'package:vasco/services/photo_service.dart';
import 'package:vasco/services/geocoding_service.dart';
import '../widget/custom_bottom_nav_bar.dart';
import 'package:vasco/screens/map_page.dart';

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
      const _FeedPage(),       // 0 - Home
      const FriendsPage(),     // 1 - Friends
      Container(),             // 2 - (neutilizat)
      MapPage(),               // 3 - Map
      const ProfileScreen(),   // 4 - Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
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
          if (index == 2) {
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

// ─── Feed real din Firestore ──────────────────────────────────────────────────

class _FeedPage extends StatelessWidget {
  const _FeedPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('location_photos')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
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
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.photo_library_outlined, size: 36, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 16),
                const Text('Nicio postare încă', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                const Text('Apasă butonul central pentru a posta prima locație.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 0, bottom: 120),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _storiesRow();
            final data = docs[index - 1].data() as Map<String, dynamic>;
            return _PostCard(data: data);
          },
        );
      },
    );
  }

  Widget _storiesRow() {
    const stories = [
      {'name': 'Tu',     'c1': Color(0xFF4F46E5), 'c2': Color(0xFF7C3AED), 'isMe': true},
      {'name': 'Alex',   'c1': Color(0xFF667EEA), 'c2': Color(0xFF764BA2)},
      {'name': 'Maria',  'c1': Color(0xFFF093FB), 'c2': Color(0xFFF5576C)},
      {'name': 'Andrei', 'c1': Color(0xFF4FACFE), 'c2': Color(0xFF00F2FE)},
      {'name': 'Elena',  'c1': Color(0xFF43E97B), 'c2': Color(0xFF38F9D7)},
      {'name': 'Radu',   'c1': Color(0xFFFA709A), 'c2': Color(0xFFFEE140)},
    ];
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: stories.length,
        itemBuilder: (_, i) {
          final s = stories[i];
          final c1 = s['c1']! as Color;
          final c2 = s['c2']! as Color;
          final isMe = s['isMe'] == true;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58, height: 58,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]), shape: BoxShape.circle),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                      ),
                      child: isMe
                          ? const Icon(Icons.add_rounded, color: Colors.white, size: 24)
                          : Center(child: Text((s['name']! as String)[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19))),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(s['name']! as String, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
              ],
            ),
          );
        },
      ),
    );
  }

}

// ─── Card individual cu geocoding lazy + cache ────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _PostCard({required this.data});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  // Cache static partajat între toate cardurile din sesiune
  static final Map<String, String> _geoCache = {};

  String? _locationLabel;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final d = widget.data;

    // 1. Deja avem locația completă salvată în document
    final stored = d['locationName'] as String? ?? d['countryName'] as String?;
    if (stored != null && stored.isNotEmpty) {
      if (mounted) setState(() => _locationLabel = stored);
      return;
    }

    // 2. Geocodăm din lat/lng
    final lat = (d['latitude']  as num?)?.toDouble();
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
    final label  = result ?? 'Locație';
    _geoCache[key] = label;
    if (mounted) setState(() => _locationLabel = label);
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours  < 24)  return 'acum ${diff.inHours}h';
    if (diff.inDays   < 7)   return 'acum ${diff.inDays}z';
    return 'acum ${diff.inDays ~/ 7} săpt';
  }

  @override
  Widget build(BuildContext context) {
    final d            = widget.data;
    final imageUrl     = d['imageUrl']     as String? ?? '';
    final displayName  = d['displayName']  as String? ?? 'Utilizator';
    final userPhotoUrl = d['userPhotoUrl'] as String? ?? '';
    final createdAt    = d['createdAt']    as Timestamp?;

    final locationLabel = _locationLabel ?? '…';
    final timeLabel     = _timeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: userPhotoUrl.isEmpty
                      ? const Icon(Icons.person_rounded, color: Color(0xFF9CA3AF))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text('$locationLabel · $timeLabel',
                                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Color(0xFFD1D5DB)),
              ],
            ),
          ),
          // ── Imagine ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl,
                          width: double.infinity, height: 280, fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => _placeholder())
                      : _placeholder(),
                  Positioned(
                    bottom: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(locationLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Acțiuni ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                _btn(Icons.favorite_border_rounded),
                const SizedBox(width: 18),
                _btn(Icons.chat_bubble_outline_rounded),
                const SizedBox(width: 18),
                _btn(Icons.send_rounded),
                const Spacer(),
                _btn(Icons.bookmark_border_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
      height: 280,
      color: const Color(0xFFF3F4F6),
      child: const Center(child: Icon(Icons.image_rounded, size: 52, color: Color(0xFF9CA3AF))));

  Widget _btn(IconData icon) => Icon(icon, size: 22, color: const Color(0xFF374151));
}
