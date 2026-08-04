import 'package:flutter/material.dart';

/// Abhaya Design System — Color Tokens (Premium Cyan/Teal)
class AppColors {
  AppColors._();

  // ── Background (Dark Premium) ──────────────────────────────────────────
  static const Color bgDeep   = Color(0xFF0B1020);
  static const Color bgMid    = Color(0xFF0B1020); // Merged backgrounds for cleaner look
  static const Color bgSurface= Color(0xFF0B1020);
  static const Color bgCard   = Color(0xFF1C2230);
  static const Color cardBorder = Color(0xFF2A3945);

  // ── Primary Palette (Bright Cyan/Teal) ──────────────────────────────────────────
  static const Color primaryBlue   = Color(0xFF18E7D3); // Primary Accent
  static const Color primaryLight  = Color(0xFF1DE9D6); // Button
  static const Color primaryDark   = Color(0xFF0CB6D4); // For Gradient
  static const Color hoverTeal     = Color(0xFF2AF2E0); // Hover
  static const Color danger        = Color(0xFFFF2E63); // Danger
  static const Color purpleAccent  = Color(0xFFA73EF7); // Purple

  // Legacy mappings to prevent breaking changes while transitioning
  static const Color accentTeal    = primaryBlue;
  static const Color accentAmber   = Color(0xFFF59E0B);
  static const Color accentCrimson = danger;
  static const Color accentTealDark = primaryDark;

  // ── Gradient ─────────────────────────────────────────────────────────
  static const List<Color> blueGradient = [primaryBlue, primaryDark];
  static const List<Color> tealGradient = blueGradient; // Legacy mapping

  // ── Glass Layer Tokens ────────────────────────────────────────────────────
  static const Color glassFill        = Color(0x0AFFFFFF);
  static const Color glassBorder      = cardBorder; 
  static const Color glassBorderFocus = Color(0x33FFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8B3C2);
  static const Color textMuted     = Color(0xFF64748B);

  // ── Status / State ────────────────────────────────────────────────────────
  static const Color statusSafe      = primaryBlue;
  static const Color statusSuspect   = accentAmber;
  static const Color statusThreat    = danger;
  static const Color statusOffline   = Color(0xFF64748B);

  // ── Transparent Shades ────────────────────────────────────────────────────
  static Color blueGlow10  = primaryBlue.withValues(alpha: 0.10);
  static Color blueGlow20  = primaryBlue.withValues(alpha: 0.20);
  static Color tealGlow10  = blueGlow10; // Legacy mapping
  static Color tealGlow20  = primaryBlue.withValues(alpha: 0.35); // Glow from requirements
  static Color crimsonGlow = danger.withValues(alpha: 0.25);
  static Color amberGlow   = accentAmber.withValues(alpha: 0.20);
}
