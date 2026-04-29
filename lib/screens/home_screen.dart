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
      _buildFeedPlaceholder(), // 0 - Home
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

    // 3. Upload foto + salvare locație
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se încarcă poza...')),
      );
    }

    await MyPhotoService.uploadPhoto(
      userId: userModel.id,
      displayName: userModel.displayName ?? 'Unknown',
      userPhotoUrl: userModel.photoUrl,
      latitude: pos.latitude,
      longitude: pos.longitude,
      imageFile: File(pickedFile.path),
    );

    // 4. Detectează țara și actualizează Firestore
    final geoJsonString =
        await rootBundle.loadString('assets/custom.geo.json');
    final geoJsonData = json.decode(geoJsonString) as Map<String, dynamic>;
    final detected =
        MapboxHelper.detectCountry(pos.latitude, pos.longitude, geoJsonData);

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

  Widget _buildFeedPlaceholder() {
    final posts = <Map<String, dynamic>>[
      {'user': 'Alexandru M.', 'location': 'București, România', 'time': '2 ore', 'c1': const Color(0xFF667EEA), 'c2': const Color(0xFF764BA2)},
      {'user': 'Maria P.', 'location': 'Cluj-Napoca, România', 'time': '5 ore', 'c1': const Color(0xFFF093FB), 'c2': const Color(0xFFF5576C)},
      {'user': 'Andrei K.', 'location': 'Paris, Franța', 'time': '1 zi', 'c1': const Color(0xFF4FACFE), 'c2': const Color(0xFF00F2FE)},
      {'user': 'Elena V.', 'location': 'Barcelona, Spania', 'time': '2 zile', 'c1': const Color(0xFF43E97B), 'c2': const Color(0xFF38F9D7)},
      {'user': 'Radu S.', 'location': 'Londra, UK', 'time': '3 zile', 'c1': const Color(0xFFFA709A), 'c2': const Color(0xFFFEE140)},
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final c1 = post['c1'] as Color;
        final c2 = post['c2'] as Color;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c1, c2]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (post['user'] as String)[0],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['user'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${post['location']} · acum ${post['time']}',
                                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 210,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c1, c2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(Icons.image_rounded, size: 52, color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(post['location'] as String, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  children: [
                    _feedAction(Icons.favorite_border_rounded, '${12 + index * 7}'),
                    const SizedBox(width: 18),
                    _feedAction(Icons.chat_bubble_outline_rounded, '${3 + index * 2}'),
                    const SizedBox(width: 18),
                    _feedAction(Icons.send_rounded, null),
                    const Spacer(),
                    _feedAction(Icons.bookmark_border_rounded, null),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _feedAction(IconData icon, String? count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF374151)),
        if (count != null) ...[
          const SizedBox(width: 5),
          Text(count, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
