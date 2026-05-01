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
    // Folosim UserProvider pentru a obține datele actuale din Firestore
    final user = context.read<UserProvider>().user; 
    if (user != null) {
      _nameController.text = user.displayName ?? "";
      _bioController.text = user.biography ?? "";
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
      final user = context.read<UserProvider>().user;
      final userRepo = context.read<UserRepository>();
      String? imageUrl = user?.photoUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('avatars/${user!.id}.jpg');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // Actualizează în Firestore
      await userRepo.updateUserProfile(user!.id, {
        'displayName': _nameController.text,
        'bio': _bioController.text,
        'photoUrl': imageUrl,
      });

      if (mounted) {
        // Așteaptă puțin pentru ca stream-ul să se actualizeze
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editează Profil")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nume",
                    hintText: "Introdu-ți numele",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Bio",
                    hintText: "Spune-ne ceva despre tine",
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text("Salvează"),
                ),
              ],
            ),
          ),
    );
  }
}