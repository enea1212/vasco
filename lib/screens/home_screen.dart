import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/services/auth_service.dart';
import 'package:vasco/screens/profile_page.dart';
import '../widget/custom_bottom_nav_bar.dart';
import 'package:vasco/screens/map_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Lista de ecrane pentru navigare
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildFeedPlaceholder(), // 0 - Home
      _buildPlaceholder("Friends"), // 1 - Friends
      Container(), // 2 - Camera
      MapPage(), // 3 - Map
      const ProfileScreen(), // 4 - Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final postRepo = context.read<PostRepository>();

    // Am eliminat DefaultTabController de aici
    return Scaffold(
      extendBody: true, // Crucial: conținutul trece sub bara de navigare
      appBar: AppBar(
        title: const Text('Vasco'),
        centerTitle: true,
        // AM ELIMINAT "bottom: const TabBar(...)" pentru a scoate bara albă
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) {
            _showUploadMenu(context, user, postRepo);
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
      ),
    );
  }

  void _showUploadMenu(BuildContext context, dynamic user, PostRepository postRepo) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fă o poză cu camera'),
              onTap: () {
                Navigator.pop(context);
                postRepo.uploadPost(user.id, "New Post", ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Alege din galerie'),
              onTap: () {
                Navigator.pop(context);
                postRepo.uploadPost(user.id, "New Post", ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedPlaceholder() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(10),
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text("Prieten ${index + 1}"),
                subtitle: const Text("Postat acum 2 ore"),
              ),
              Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.image, size: 50)),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Aceasta este o descriere a pozei..."),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.grey)),
    );
  }
}