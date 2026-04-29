import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vasco/providers/user_provider.dart';
import '../repository/user_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

void _loadCurrentData() {
  // Folosim UserProvider în loc de AuthService pentru că UserProvider conține datele din Firestore (inclusiv bio)
  final user = context.read<UserProvider>().user; 
  if (user != null) {
    _nameController.text = user.displayName ?? "";
    _bioController.text = user.biography ?? ""; // Acum va prelua valoarea corectă
  }
}

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }
Future<void> _updateProfile() async {
  setState(() => _isLoading = true);
  try {
    // Citim user-ul tot din UserProvider pentru a avea acces la ID și photoUrl-ul actual
    final user = context.read<UserProvider>().user;
    final userRepo = context.read<UserRepository>();
    String? imageUrl = user?.photoUrl;

    if (_imageFile != null) {
      final ref = FirebaseStorage.instance.ref().child('avatars/${user!.id}.jpg');
      await ref.putFile(_imageFile!);
      imageUrl = await ref.getDownloadURL();
    }

    await userRepo.updateUserProfile(user!.id, {
      'displayName': _nameController.text,
      'bio': _bioController.text, // Se va salva valoarea din controller
      'photoUrl': imageUrl,
    });

    if (mounted) Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  } finally {
    setState(() => _isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editează Profil")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null ? const Icon(Icons.camera_alt) : null,
                  ),
                ),
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Nume")),
                TextField(controller: _bioController, decoration: const InputDecoration(labelText: "Bio")),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _updateProfile, child: const Text("Salvează"))
              ],
            ),
          ),
    );
  }
}