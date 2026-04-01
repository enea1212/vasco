import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/services/auth_service.dart';
import 'package:vasco/screens/profile_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final FirebaseFirestore _db = FirebaseFirestore.instance;
    final postRepo = context.read<PostRepository>();
   

return DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Vasco'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
        bottom: const TabBar(
          isScrollable: false,
          tabs: [
            Tab(icon: Icon(Icons.home), text: "Feed"),
            Tab(icon: Icon(Icons.map), text: "Map"),
            Tab(icon: Icon(Icons.local_fire_department), text: "Swipe"),
            Tab(icon: Icon(Icons.person), text: "Profil"),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _buildFeedPlaceholder(),
          _buildPlaceholder("Harta (Google Maps)"),
          _buildPlaceholder("Tinder Swipe Area"),
          ProfileScreen(),
        ],
      ),
      
      // <<< ADAUGĂ BUTONUL EXACT AICI >>>
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aici vei apela funcția de upload definită în repository-ul tău
          // Exemplu: 
          // if (user != null) postRepo.uploadPost(user.uid, "Descriere...");
if (user == null) return;

    // Afișăm un meniu (Bottom Sheet) pentru a alege sursa pozei
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fă o poză cu camera'),
              onTap: () {
                Navigator.pop(context); // Închidem meniul
                postRepo.uploadPost(user.id, "New Post", ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from galery'),
              onTap: () {
                Navigator.pop(context); // Închidem meniul
                postRepo.uploadPost(user.id, "New Post", ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );



          print("Butonul de postare a fost apăsat!");
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    ),
  );
}
  

  // Structura de bază pentru Feed
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
                child: Text("Aceasta este o descriere a pozei postate pe hartă..."),
              ),
            ],
          ),
        );
      },
    );
  }


// Widget _buildProfilePage(BuildContext context, user, authService) {
//   return Column(
//     children: [
//       const SizedBox(height: 20),
//       const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
//       const SizedBox(height: 16),
//       Text(user?.displayName ?? "Utilizator", 
//            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//       Text(user?.email ?? ""),
//       const SizedBox(height: 16),
//       ElevatedButton.icon(
//         onPressed: () => authService.signOut(),
//         icon: const Icon(Icons.logout),
//         label: const Text("Deconectare"),
//         style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
//       ),
//       const Divider(height: 32),
//       const Text("Postările mele", style: TextStyle(fontWeight: FontWeight.bold)),
//       const SizedBox(height: 8),
      
//       Expanded(
//         child: StreamBuilder<QuerySnapshot>(
//           stream: FirebaseFirestore.instance
//               .collection('posts')
//               .where('userId', isEqualTo: user?.id) // Folosește id din UserModel
//               .orderBy('createdAt', descending: true)
//               .snapshots(),
//           builder: (context, snapshot) {
//             if (snapshot.hasError) return const Center(child: Text("Eroare la încărcarea postărilor"));
//             if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

//             final docs = snapshot.data?.docs ?? [];
//             if (docs.isEmpty) return const Center(child: Text("Nu ai nicio postare încă."));

//             return GridView.builder(
//               padding: const EdgeInsets.all(8),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 3,
//                 crossAxisSpacing: 5,
//                 mainAxisSpacing: 5,
//               ),
//               itemCount: docs.length,
//               itemBuilder: (context, index) {
//                 final data = docs[index].data() as Map<String, dynamic>;
//                 final imageUrl = data['imageUrl'] ?? "";
//                 final description = data['description'] ?? "Nicio descriere";

//                 return GestureDetector(
//                   onTap: () {
//                     // AFIȘARE POZĂ MARE + DESCRIERE
//                     showDialog(
//                       context: context,
//                       builder: (context) => Dialog(
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min, // Dialogul se adaptează după conținut
//                           children: [
//                             ClipRRect(
//                               borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
//                               child: Image.network(imageUrl, fit: BoxFit.contain),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Text(
//                                 description,
//                                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                             TextButton(
//                               onPressed: () => Navigator.pop(context),
//                               child: const Text("Închide"),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: Image.network(
//                       imageUrl,
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ),
//     ],
//   );
// }

  Widget _buildPlaceholder(String text) {
    return Center(child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.grey)));
  }
}