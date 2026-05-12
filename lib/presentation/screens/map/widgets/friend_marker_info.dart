import 'package:flutter/material.dart';
import 'package:vasco/domain/entities/friend_location_entity.dart';
import 'package:vasco/presentation/screens/profile/user_profile_screen.dart';

/// Bottom sheet / popup that displays info about a friend on the map.
/// Extracted from map_page.dart tap handler logic.
class FriendMarkerInfo extends StatelessWidget {
  final String friendId;
  final FriendLocationEntity friendData;

  const FriendMarkerInfo({
    super.key,
    required this.friendId,
    required this.friendData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: friendData.photoUrl != null
                    ? NetworkImage(friendData.photoUrl!)
                    : null,
                backgroundColor: const Color(0xFFF3F4F6),
                child: friendData.photoUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF9CA3AF),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friendData.displayName ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (friendData.hasLocation)
                      Row(
                        children: const [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: Color(0xFF22C55E),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Active location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: friendId,
                        initialDisplayName: friendData.displayName,
                        initialPhotoUrl: friendData.photoUrl,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  /// Shows this widget as a bottom sheet.
  static void show(
    BuildContext context, {
    required String friendId,
    required FriendLocationEntity friendData,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => FriendMarkerInfo(
        friendId: friendId,
        friendData: friendData,
      ),
    );
  }
}
