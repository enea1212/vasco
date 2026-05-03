import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/providers/user_provider.dart';

class DatingPreferencesScreen extends StatefulWidget {
  const DatingPreferencesScreen({super.key});

  @override
  State<DatingPreferencesScreen> createState() => _DatingPreferencesScreenState();
}

class _DatingPreferencesScreenState extends State<DatingPreferencesScreen> {
  String? _myGender;
  String? _interestedIn;
  final Set<String> _selectedGoals = {};
  bool _isSaving = false;

  static const _goals = [
    ('parties', Icons.celebration_outlined, 'Petreceri'),
    ('tourism', Icons.photo_camera_outlined, 'Obiective turistice'),
    ('drink_buddy', Icons.local_bar_outlined, 'Drink buddy'),
    ('workout', Icons.fitness_center_outlined, 'Workout / sport'),
    ('restaurants', Icons.restaurant_outlined, 'Explorat restaurante'),
    ('concerts', Icons.music_note_outlined, 'Concerte & festivaluri'),
    ('hiking', Icons.terrain_outlined, 'Hiking & aventuri'),
    ('networking', Icons.handshake_outlined, 'Networking'),
    ('movies', Icons.movie_outlined, 'Movie nights'),
    ('volunteering', Icons.volunteer_activism_outlined, 'Voluntariat'),
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() {
      _myGender = user.gender;
      _interestedIn = user.preferences?['interestedIn'];
      final saved = user.interests ?? [];
      _selectedGoals
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _save() async {
    if (_myGender == null || _interestedIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectează genul tău și pe cine vrei să întâlnești.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'gender': _myGender,
        'interests': _selectedGoals.toList(),
        'preferences.interestedIn': _interestedIn,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferințe salvate!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferințe dating'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Eu sunt'),
                  const SizedBox(height: 12),
                  _genderRow(),
                  const SizedBox(height: 28),
                  _sectionTitle('Vreau să întâlnesc'),
                  const SizedBox(height: 12),
                  _interestedInRow(),
                  const SizedBox(height: 28),
                  _sectionTitle('De ce vreau să cunosc lume nouă'),
                  const SizedBox(height: 4),
                  const Text(
                    'Poți selecta mai multe',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 12),
                  _goalsGrid(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Salvează preferințele',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _genderRow() {
    return Row(
      children: [
        _genderCard('male', Icons.male_rounded, 'Bărbat'),
        const SizedBox(width: 12),
        _genderCard('female', Icons.female_rounded, 'Femeie'),
      ],
    );
  }

  Widget _genderCard(String value, IconData icon, String label) {
    final selected = _myGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _myGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4F46E5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _interestedInRow() {
    return Row(
      children: [
        _interestedChip('male', 'Bărbați'),
        const SizedBox(width: 8),
        _interestedChip('female', 'Femei'),
        const SizedBox(width: 8),
        _interestedChip('both', 'Oricine'),
      ],
    );
  }

  Widget _interestedChip(String value, String label) {
    final selected = _interestedIn == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _interestedIn = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF2FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? const Color(0xFF4F46E5) : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalsGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _goals.map((g) {
        final key = g.$1;
        final icon = g.$2;
        final label = g.$3;
        final selected = _selectedGoals.contains(key);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedGoals.remove(key);
            } else {
              _selectedGoals.add(key);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF4F46E5) : Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
