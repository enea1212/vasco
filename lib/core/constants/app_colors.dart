import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand / Primary (Indigo) ──────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFFEDE9FE); // indigo light bg / track
  static const Color primaryMid = Color(0xFFEEF2FF);   // indigo mid bg

  // ── Danger / Error (Red) ──────────────────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // ── Purple ────────────────────────────────────────────────────────────────
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFF3E8FF);

  // ── Rose / Pink ───────────────────────────────────────────────────────────
  static const Color rose = Color(0xFFE11D48);
  static const Color roseLi = Color(0xFFFFF1F2);
  static const Color rosePink = Color(0xFFDB2777);       // matches/swipe pink
  static const Color rosePinkLight = Color(0xFFFDA4AF);  // rose light pink chip

  // ── Green / Emerald ───────────────────────────────────────────────────────
  static const Color green = Color(0xFF22C55E);           // map border green
  static const Color greenDark = Color(0xFF16A34A);       // map label green
  static const Color greenEmerald = Color(0xFF059669);    // profile badge
  static const Color greenLight = Color(0xFFD1FAE5);      // emerald light bg
  static const Color greenLighter = Color(0xFFF0FDF4);   // map tag bg
  static const Color greenSpotify = Color(0xFF1DB954);    // Spotify green

  // ── Instagram Gradient ────────────────────────────────────────────────────
  static const Color igOrange = Color(0xFFF09433);
  static const Color igOrangeRed = Color(0xFFE6683C);
  static const Color igRed = Color(0xFFDC2743);
  static const Color igPink = Color(0xFFCC2366);
  static const Color igPurple = Color(0xFFBC1888);

  // ── Amber / Sky (profile badges) ──────────────────────────────────────────
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color skyLight = Color(0xFFE0F2FE);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF3F4F6); // slightly darker card bg
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFD1D5DB);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // ── Cards & Shadows ───────────────────────────────────────────────────────
  static const Color cardShadow = Color(0x0D000000);      // black ~5%
  static const Color cardShadowLight = Color(0x0A000000); // black ~4%
}
