import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/repository/post_repository.dart';
import 'package:vasco/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Funcție helper pentru coloanele de statistici
  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final postRepo = context.read<PostRepository>();
    final user = authService.currentUser;

    if (user == null) {
      return const Center(child: Text("Utilizator neautentificat"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        // 1. Header: Poza de profil + Statistici
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 40, 
                child: Icon(Icons.person, size: 40)
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn("Postări", "0"), 
                    _buildStatColumn("Followers", "0"),
                    _buildStatColumn("Following", "0"),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. USERNAME și EMAIL (Exact aici trebuiau adăugate)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? "Utilizator", 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 2),
              Text(
                user.email ?? "", 
                style: const TextStyle(color: Colors.grey, fontSize: 14)
              ),
            ],
          ),
        ),

        // 3. Buton Deconectare
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => authService.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text("Deconectare"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),

        const Divider(height: 32),
        const Center(child: Text("Postările mele", style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        
        // 4. Grid-ul de postări
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: user.id)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Eroare la încărcare"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text("Nicio postare."));

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final docId = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  
                  return GestureDetector(
                    onTap: () => _showImageDialog(context, docId, data, postRepo),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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

  // Celelalte funcții de dialog (_showImageDialog, _showEditDialog, etc.) rămân la fel jos...
  void _showImageDialog(BuildContext context, String postId, Map<String, dynamic> data, PostRepository postRepo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditDialog(context, postId, data['description'], postRepo);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, postId, data['imageUrl'], postRepo);
                  },
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Image.network(data['imageUrl']),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(data['description'] ?? "", style: const TextStyle(fontSize: 16)),
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
        title: const Text("Editează"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anulează")),
          ElevatedButton(
            onPressed: () async {
              await postRepo.editPost(postId, controller.text);
              Navigator.pop(context);
            },
            child: const Text("Salvează"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String postId, String imageUrl, PostRepository postRepo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ștergi postarea?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Nu")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await postRepo.deletePost(postId, imageUrl);
              Navigator.pop(context);
            },
            child: const Text("Șterge"),
          ),
        ],
      ),
    );
  }
}