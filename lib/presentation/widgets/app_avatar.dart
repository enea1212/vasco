import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.photoUrl,
    this.radius = AppSizes.avatarRadiusSm,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage:
          (photoUrl?.isNotEmpty == true) ? NetworkImage(photoUrl!) : null,
      backgroundColor: backgroundColor ?? AppColors.surfaceAlt,
      child: (photoUrl?.isNotEmpty == true)
          ? null
          : Icon(
              Icons.person_rounded,
              color: iconColor ?? AppColors.textHint,
              size: iconSize ?? radius * 0.8,
            ),
    );
  }
}
