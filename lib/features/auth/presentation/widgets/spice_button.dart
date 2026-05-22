import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SpiceButton
/// The primary CTA button used throughout the app.
/// Flame gradient + loading spinner + disabled state all baked in.
/// ─────────────────────────────────────────────────────────────────────────────
class SpiceButton extends StatelessWidget {
  const SpiceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.width = double.infinity,
    this.height = 56,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final double width;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && !isLoading && onPressed != null;

    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: isActive ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: isActive
                ? AppColors.primaryGradient
                : const LinearGradient(
                    colors: [AppColors.border, AppColors.border],
                  ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// SpiceOutlineButton
/// Secondary outlined variant — used for "Sign Up" / "Back" actions.
/// ─────────────────────────────────────────────────────────────────────────────
class SpiceOutlineButton extends StatelessWidget {
  const SpiceOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
