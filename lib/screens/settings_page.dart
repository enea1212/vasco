import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/services/auth_service.dart';
import 'package:vasco/services/location_groups_service.dart';
import 'package:vasco/repository/edit_profile.dart';
<<<<<<< HEAD
=======
import 'package:vasco/screens/dating_preferences_screen.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
import 'package:vasco/features/auth/screens/login_screen.dart';
>>>>>>> origin/tinder

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _privacyLoading = false;
  bool? _locationSharing;
  bool _locationLoading = false;
  String? _loadedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>().user;
    if (user != null && _loadedForUserId != user.id) {
      _loadedForUserId = user.id;
      _loadVisibility(user.id);
    }
  }

  Future<void> _loadVisibility(String uid) async {
    try {
      final vis = await LocationGroupsService.getVisibility(uid);
      if (mounted) setState(() => _locationSharing = vis != 'none');
    } catch (_) {
      if (mounted) setState(() => _locationSharing = true);
    }
  }

  Future<void> _toggleLocationSharing(String uid) async {
    final current = _locationSharing ?? true;
    setState(() => _locationLoading = true);
    try {
      await LocationGroupsService.setVisibility(uid, current ? 'none' : 'all');
      if (mounted) setState(() => _locationSharing = !current);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _togglePrivacy(String uid, bool currentValue) async {
    setState(() => _privacyLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isPrivate': !currentValue});
    } finally {
      if (mounted) setState(() => _privacyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Secțiunea Cont ─────────────────────────────────────────────────
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: (user.photoUrl?.isNotEmpty == true)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    backgroundColor: const Color(0xFFF3F4F6),
                    child: (user.photoUrl?.isNotEmpty == true)
                        ? null
                        : const Icon(Icons.person_rounded, color: Color(0xFF9CA3AF), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'Utilizator',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Secțiunea Profil ───────────────────────────────────────────────
          const Text(
            'PROFIL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.edit_rounded,
            iconBg: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF4F46E5),
            label: 'Editează profilul',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.favorite_outline_rounded,
            iconBg: const Color(0xFFFFF1F2),
            iconColor: const Color(0xFFE11D48),
            label: 'Interesele Mele',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DatingPreferencesScreen()),
            ),
          ),
          const SizedBox(height: 28),

          // ── Secțiunea Confidențialitate ────────────────────────────────────
          const Text(
            'CONFIDENȚIALITATE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.visibility_rounded,
                        color: Color(0xFF4F46E5), size: 19),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vizibilitate locație',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          _locationSharing == true
                              ? 'Locația ta e vizibilă prietenilor'
                              : 'Locația ta e ascunsă',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _locationLoading || _locationSharing == null
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF4F46E5)),
                        )
                      : Switch(
                          value: _locationSharing!,
                          onChanged: (_) => _toggleLocationSharing(user.id),
                          activeThumbColor: const Color(0xFF4F46E5),
                          activeTrackColor: const Color(0xFFEDE9FE),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Color(0xFF7C3AED), size: 19),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cont privat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          user.isPrivate
                              ? 'Doar prietenii îți pot vedea profilul'
                              : 'Oricine îți poate vedea profilul',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _privacyLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF7C3AED)),
                        )
                      : Switch(
                          value: user.isPrivate,
                          onChanged: (_) =>
                              _togglePrivacy(user.id, user.isPrivate),
                          activeThumbColor: const Color(0xFF7C3AED),
                          activeTrackColor: const Color(0xFFEDE9FE),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 28),

          // ── Secțiunea Altele ───────────────────────────────────────────────
          const Text(
            'ALTELE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.logout_rounded,
            iconBg: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFEF4444),
            label: 'Deconectare',
            labelColor: const Color(0xFFEF4444),
            showArrow: false,
            onTap: () => _confirmLogout(context, authService),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    Color? labelColor,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: labelColor ?? const Color(0xFF111827),
                ),
              ),
            ),
            if (showArrow)
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService authService) {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
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
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deconectare',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ești sigur că vrei să te deconectezi?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: const Text('Anulează', style: TextStyle(color: Color(0xFF374151))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await authService.signOut();
                        nav.popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Deconectează'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}