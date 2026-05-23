import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/spice_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final result = await ref
        .read(authNotifierProvider.notifier)
        .forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate to OTP screen in reset mode
      context.pushNamed(
        RouteNames.otp,
        queryParameters: {
          'email': _emailCtrl.text.trim(),
          'purpose': 'reset',
          'name': '',
        },
        // isReset handled by route_names.resetPassword, but we reuse otp route
        // with purpose=reset so OtpScreen knows to show password fields after.
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? AppStrings.genericError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle glow
          Positioned(
            top: 100,
            left: -120,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Back ───────────────────────────────────────────────
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          color: AppColors.surfaceAlt,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 40),

                    // ── Lock icon badge ────────────────────────────────────
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ).animate().scale(
                          begin: const Offset(0.7, 0.7),
                          delay: 100.ms,
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        ),

                    const SizedBox(height: 24),

                    Text(
                      AppStrings.forgotTitle,
                      style: GoogleFonts.syne(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),

                    const SizedBox(height: 8),

                    Text(
                      AppStrings.forgotSubhead,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 40),

                    // ── Email ──────────────────────────────────────────────
                    AuthTextField(
                      label: AppStrings.emailLabel,
                      hint: AppStrings.emailHint,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.alternate_email_rounded,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
                        if (!re.hasMatch(v.trim())) {
                          return AppStrings.invalidEmail;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),

                    const SizedBox(height: 32),

                    SpiceButton(
                      label: AppStrings.sendOtp,
                      onPressed: _submit,
                      isLoading: _isLoading,
                      icon: Icons.send_rounded,
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 28),

                    // ── Back to login ──────────────────────────────────────
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        label: Text(
                          'Back to Sign In',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
