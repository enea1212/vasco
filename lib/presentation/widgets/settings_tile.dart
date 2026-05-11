import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showArrow = true,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.tileHPadding,
          vertical: AppSizes.tileVPadding,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadowLight,
              blurRadius: AppSizes.shadowBlur,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.iconBoxSize,
              height: AppSizes.iconBoxSize,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppSizes.radiusIcon),
              ),
              child: Icon(icon, color: iconColor, size: AppSizes.iconSize),
            ),
            const SizedBox(width: AppSizes.spacingMd),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.tileTitle.copyWith(
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.divider,
              ),
          ],
        ),
      ),
    );
  }
}
