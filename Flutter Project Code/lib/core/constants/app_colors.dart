import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AppColors
/// Single source of truth for every colour used across the app.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  /// True page/scaffold background — the deepest layer.
  static const Color background = Color(0xFF0F0F0F);

  /// Default card / bottom-sheet surface.
  static const Color surface = Color(0xFF161616);

  /// Slightly lighter surface for nested cards, input fills.
  static const Color surfaceAlt = Color(0xFF1A1A1A);

  /// Elevated surface — headers, nav bars.
  static const Color surfaceHigh = Color(0xFF222222);

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF333333);

  // ── Primary / Accent (Flame Orange) ──────────────────────────────────────────
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFF7931E);

  /// Subtle tinted overlay — e.g. selected tab background.
  static const Color primaryTint = Color(0x1AFF6B35); // 10% opacity

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textMuted = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF444444);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color successTint = Color(0x1A4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFEF5350);
  static const Color errorTint = Color(0x1AEF5350);
  static const Color info = Color(0xFF4FACFE); // Delivery-mode blue

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceAlt, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient splashGlow = RadialGradient(
    center: Alignment.center,
    radius: 0.7,
    colors: [Color(0x33FF6B35), Color(0x00FF6B35)],
  );
}
