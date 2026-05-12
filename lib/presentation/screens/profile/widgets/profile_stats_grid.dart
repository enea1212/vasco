import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';

/// 2×2 stats grid for the own-profile screen.
/// Tapping "Țări vizitate" calls [onCountriesTap]; tapping "Prieteni" calls [onFriendsTap].
class ProfileStatsGrid extends StatelessWidget {
  final int countries;
  final int friends;
  final int photos;
  final VoidCallback onCountriesTap;
  final VoidCallback onFriendsTap;

  const ProfileStatsGrid({
    super.key,
    required this.countries,
    required this.friends,
    required this.photos,
    required this.onCountriesTap,
    required this.onFriendsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCountriesTap,
                  child: _StatCard(
                    icon: Icons.public_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryMid,
                    value: '$countries',
                    label: 'Countries visited',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onFriendsTap,
                  child: _StatCard(
                    icon: Icons.people_alt_rounded,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleLight,
                    value: '$friends',
                    label: 'Prieteni',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.camera_alt_rounded,
            iconColor: AppColors.greenEmerald,
            iconBg: AppColors.greenLight,
            value: '$photos',
            label: 'Fotografii',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
