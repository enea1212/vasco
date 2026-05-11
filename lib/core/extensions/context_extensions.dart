import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';

/// Convenience extensions on [BuildContext].
///
/// Color and text-style tokens live in [AppColors] and [AppTextStyles] as
/// plain `static const` members — use them directly:
///
///   ```dart
///   Text('Hello', style: TextStyle(color: AppColors.primary));
///   ```
///
/// This extension exposes only the runtime-contextual helpers that genuinely
/// need a [BuildContext].
extension BuildContextX on BuildContext {
  // ── Screen geometry ───────────────────────────────────────────────────────
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  // ── Theme ─────────────────────────────────────────────────────────────────
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Design-token shortcuts ────────────────────────────────────────────────
  double get pagePadding => AppSizes.pagePadding;
  double get cardPadding => AppSizes.cardPadding;
}
