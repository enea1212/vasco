import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand / Primary (Indigo) ──────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0x1A4F46E5); // primary/10% – icon bg
  static const Color primaryMid = Color(0x264F46E5);   // primary/15% – accent bg

  // ── Danger / Error (Red) ──────────────────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0x1AEF4444);  // danger/10%

  // ── Purple ────────────────────────────────────────────────────────────────
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0x1A7C3AED);  // purple/10%

  // ── Rose / Pink ───────────────────────────────────────────────────────────
  static const Color rose = Color(0xFFE11D48);
  static const Color roseLi = Color(0x1AE11D48);       // rose/10%
  static const Color rosePink = Color(0xFFDB2777);
  static const Color rosePinkLight = Color(0x1ADB2777); // rose-pink/10%

  // ── Green / Emerald ───────────────────────────────────────────────────────
  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color greenEmerald = Color(0xFF059669);
  static const Color greenLight = Color(0x1A22C55E);   // green/10%
  static const Color greenLighter = Color(0x0D22C55E); // green/5%
  static const Color greenSpotify = Color(0xFF1DB954);

  // ── Instagram Gradient ────────────────────────────────────────────────────
  static const Color igOrange = Color(0xFFF09433);
  static const Color igOrangeRed = Color(0xFFE6683C);
  static const Color igRed = Color(0xFFDC2743);
  static const Color igPink = Color(0xFFCC2366);
  static const Color igPurple = Color(0xFFBC1888);

  // ── Amber / Sky (profile badges) ──────────────────────────────────────────
  static const Color amberLight = Color(0x1AF59E0B);   // amber/10%
  static const Color skyLight = Color(0x1A0EA5E9);     // sky/10%

  // ── Neutrals (dark theme) ─────────────────────────────────────────────────
  static const Color background = Color(0xFF07071A);
  static const Color surface = Color(0xFF13122B);
  static const Color surfaceAlt = Color(0xFF1C1B36);
  static const Color border = Color(0x1AFFFFFF);       // white/10%
  static const Color divider = Color(0x0DFFFFFF);      // white/5%

  // ── Text (dark theme) ─────────────────────────────────────────────────────
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xCCFFFFFF); // white/80%
  static const Color textMuted = Color(0x8CFFFFFF);    // white/55%
  static const Color textHint = Color(0x61FFFFFF);     // white/38%

  // ── Cards & Shadows ───────────────────────────────────────────────────────
  static const Color cardShadow = Color(0x33000000);
  static const Color cardShadowLight = Color(0x1A000000);
}
