import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textHint,
    letterSpacing: 1.2,
  );

  static const TextStyle tileTitle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle tileSubtitle = TextStyle(
    fontSize: 12,
    color: AppColors.textHint,
  );

  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: AppColors.textHint,
    fontSize: 13,
  );

  static const TextStyle dialogTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle dialogBody = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
  );

  static const TextStyle buttonText = TextStyle(
    color: AppColors.textSecondary,
  );
}
