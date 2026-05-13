import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';

class TinderCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback? onTap;

  const TinderCard({super.key, required this.profile, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = profile['displayName'] ?? 'Anonim';
    final age = profile['age'];
    final distance = profile['distance'];
    final bio = profile['bio'] as String?;
    final photos = (profile['photos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final photoUrl = photos.isNotEmpty
        ? photos.first['imageUrl'] as String?
        : profile['photoUrl'] as String?;
    final interests = List<String>.from(profile['interests'] ?? []);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fundal — poza sau placeholder
          if (photoUrl != null && photoUrl.isNotEmpty)
            Image.network(photoUrl, fit: BoxFit.cover)
          else
            Container(
              color: AppColors.surfaceAlt,
              child: const Icon(Icons.person_rounded, color: AppColors.textHint, size: 80),
            ),

          // Gradient negru jos
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
              ),
            ),
          ),

          // Conținut text jos
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (age != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$age',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                if (distance != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: interests.take(3).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),   // ClipRRect
    );   // GestureDetector
  }
}
