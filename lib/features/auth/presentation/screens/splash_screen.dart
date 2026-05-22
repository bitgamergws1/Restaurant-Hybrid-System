import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SplashScreen
/// Shown while [AuthNotifier] checks SharedPreferences for a stored token.
/// GoRouter's redirect will automatically navigate away when state settles.
///
/// Visual sequence:
///   0ms    → radial glow fades in
///   300ms  → logo scales + fades in (bouncy spring)
///   700ms  → brand name slides up + fades in
///   900ms  → tagline fades in
///   1200ms → AuthNotifier emits final state → router redirects
/// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Radial glow backdrop ─────────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGlow,
                ),
              ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),
            ),

            // ── Subtle grid texture overlay ──────────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),

            // ── Centre content ───────────────────────────────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1,
                    ),
                    color: AppColors.surfaceAlt,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/route.png',
                    fit: BoxFit.cover,
                    // Graceful fallback if asset not added yet
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      delay: 200.ms,
                      duration: 700.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // Brand name
                Text(
                  'SPICE ROUTE',
                  style: GoogleFonts.syne(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 5,
                  ),
                )
                    .animate()
                    .slideY(
                      begin: 0.4,
                      end: 0,
                      delay: 600.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Taste the Tradition',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ).animate().fadeIn(delay: 900.ms, duration: 600.ms),
              ],
            ),

            // ── Bottom loading indicator ─────────────────────────────────────
            Positioned(
              bottom: 52,
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'LOADING',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a subtle dark grid pattern for depth.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
