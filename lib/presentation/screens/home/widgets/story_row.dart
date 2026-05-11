import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';

// ─── Stories row ──────────────────────────────────────────────────────────────

class StoriesRow extends StatelessWidget {
  final dynamic currentUser;
  final List friends;

  const StoriesRow({super.key, required this.currentUser, required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        itemCount: 1 + friends.length,
        itemBuilder: (_, i) {
          if (i == 0) {
            final photo = currentUser?.photoUrl as String?;
            return _StoryItem(name: 'Tu', photoUrl: photo, isMe: true);
          }
          final friend = friends[i - 1];
          return _StoryItem(
            name: (friend.displayName as String? ?? 'Prieten').split(' ').first,
            photoUrl: friend.photoUrl as String?,
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isMe;

  const _StoryItem({required this.name, this.photoUrl, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.igOrange,
                      AppColors.igOrangeRed,
                      AppColors.igRed,
                      AppColors.igPink,
                      AppColors.igPurple,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl!)
                        : null,
                    backgroundColor: AppColors.surfaceAlt,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: AppColors.textMuted,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
