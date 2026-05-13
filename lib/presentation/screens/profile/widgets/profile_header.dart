import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/domain/entities/user_entity.dart';
import 'package:vasco/presentation/screens/profile/settings_page.dart';

class ProfileHeader extends StatelessWidget {
  final UserEntity user;
  final bool showBackButton;

  const ProfileHeader({
    super.key,
    required this.user,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (user.displayName?.isNotEmpty == true)
        ? user.displayName!
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .take(2)
              .join()
        : 'ME';

    final username =
        '@${(user.displayName ?? 'username').toLowerCase().replaceAll(' ', '_')}';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showBackButton)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundImage: (user.photoUrl?.isNotEmpty == true)
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  backgroundColor: AppColors.primaryMid,
                  child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              user.displayName ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
