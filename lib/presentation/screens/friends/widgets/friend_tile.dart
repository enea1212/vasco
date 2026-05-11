import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/core/constants/app_sizes.dart';

/// Widget de afișare pentru un prieten din lista de prieteni.
/// Primește toate datele prin parametri — fără Provider.of / context.read.
class FriendTile extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? biography;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FriendTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.biography,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.tileHPadding,
          vertical: 5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.tileHPadding,
          vertical: AppSizes.tileVPadding - 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: AppSizes.shadowBlurLg,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: (photoUrl?.isNotEmpty == true)
                  ? NetworkImage(photoUrl!)
                  : null,
              backgroundColor: AppColors.surfaceAlt,
              child: (photoUrl?.isNotEmpty == true)
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      color: AppColors.textHint,
                    ),
            ),
            const SizedBox(width: AppSizes.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (biography?.isNotEmpty == true)
                    Text(
                      biography!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              onSelected: (val) {
                if (val == 'remove') onRemove();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Elimină prieten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
